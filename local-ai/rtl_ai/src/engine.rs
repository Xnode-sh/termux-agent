//! Локальный движок: GGUF через llama-cpp-2 (=0.1.157).
//! Три приёма скорости: mmap весов, модель и контекст живут всё время работы приложения,
//! системный промпт считается ОДИН раз и переиспользуется из KV-кэша.

use std::num::NonZeroU32;
use std::time::Instant;

use llama_cpp_2::context::params::{KvCacheType, LlamaContextParams};
use llama_cpp_2::context::LlamaContext;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::sampling::LlamaSampler;
use serde::Deserialize;

use crate::guard::{self, Risk, Verdict};

/// GBNF: модель физически не может ответить ничем, кроме этого JSON.
/// Нет места «рассуждениям», болтовне и markdown — отсюда и скорость, и управляемость.
pub const GRAMMAR: &str = r#"
root    ::= "{" ws "\"cmd\":" ws str "," ws "\"explain\":" ws str "," ws "\"risk\":" ws risk ws "}"
risk    ::= "\"safe\"" | "\"write\"" | "\"danger\""
str     ::= "\"" char{1,300} "\""
char    ::= [^"\\\n] | "\\" ["\\/nt]
ws      ::= [ ]?
"#;

pub const SYSTEM_PROMPT: &str = "Ты переводишь просьбу человека в ОДНУ команду для терминала Android (Termux, bash).\n\
Отвечай только JSON: cmd — команда, explain — одно короткое объяснение по-русски простыми словами, \
risk — safe (только читает), write (меняет файлы), danger (может навредить).\n\
Если просьба непонятна или опасна — cmd: \"echo 'Уточни, что нужно'\".\n\
Примеры:\n\
Просьба: покажи файлы тут\n{\"cmd\":\"ls -la\",\"explain\":\"Показывает все файлы в этой папке\",\"risk\":\"safe\"}\n\
Просьба: сколько места на телефоне\n{\"cmd\":\"df -h /storage/emulated/0\",\"explain\":\"Показывает, сколько памяти занято и свободно\",\"risk\":\"safe\"}\n\
Просьба: сделай папку фото\n{\"cmd\":\"mkdir -p фото\",\"explain\":\"Создаёт папку фото\",\"risk\":\"write\"}";

#[derive(Debug, Clone, Copy)]
pub struct EngineConfig {
    /// Потоки = число БОЛЬШИХ ядер. На Snapdragon 8 Gen 2/3 это 4 (1 prime + 3 perf).
    /// 8 потоков на телефоне обычно МЕДЛЕННЕЕ: маленькие ядра тормозят общий шаг.
    pub threads: i32,
    /// Контекст: системный промпт (~250 ток.) + просьба + ответ. 2048 хватает с запасом.
    pub n_ctx: u32,
    pub max_new_tokens: usize,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self { threads: 4, n_ctx: 2048, max_new_tokens: 160 }
    }
}

#[derive(Debug, Deserialize)]
pub struct Suggestion {
    pub cmd: String,
    pub explain: String,
    /// Мнение модели. Итоговый риск ставит guard, не модель.
    pub risk: String,
}

#[derive(Debug)]
pub struct Answer {
    pub cmd: String,
    pub explain: String,
    /// Итоговый риск: максимум из мнения модели и вердикта guard.
    pub risk: Risk,
    pub ms_prompt: u128,
    pub ms_total: u128,
    pub tokens: usize,
}

#[derive(Debug)]
pub enum AskResult {
    Ok(Answer),
    Blocked { cmd: String, reason: String },
}

pub struct Engine {
    model: &'static LlamaModel,
    ctx: LlamaContext<'static>,
    prefix_tokens: usize,
    cfg: EngineConfig,
    pub load_ms: u128,
}

impl Engine {
    /// Грузится ОДИН раз при старте приложения (в фоне, пока показывается boot-экран).
    /// Модель и backend «утекают» в 'static намеренно: они живут до конца процесса,
    /// так контекст можно держать тёплым без self-referencing структур.
    pub fn load(path: &str, cfg: EngineConfig) -> Result<Self, Box<dyn std::error::Error>> {
        let t0 = Instant::now();
        let backend: &'static LlamaBackend = Box::leak(Box::new(LlamaBackend::init()?));

        let mparams = LlamaModelParams::default()
            .with_use_mmap(true) // веса не копируются: ОС подкачивает страницы файла по мере нужды
            .with_use_mlock(false) // на Android лимит RLIMIT_MEMLOCK мал, mlock упадёт или убьёт процесс
            .with_n_gpu_layers(0); // MVP: только CPU+NEON. GPU/NPU — отдельный замер позже
        let model: &'static LlamaModel = Box::leak(Box::new(LlamaModel::load_from_file(backend, path, &mparams)?));

        let cparams = LlamaContextParams::default()
            .with_n_ctx(NonZeroU32::new(cfg.n_ctx))
            .with_n_batch(512)
            .with_n_ubatch(512)
            .with_n_threads(cfg.threads)
            .with_n_threads_batch(cfg.threads)
            .with_type_k(KvCacheType::Q8_0) // KV-кэш вдвое меньше, качество почти то же
            .with_type_v(KvCacheType::Q8_0);
        let ctx = model.new_context(backend, cparams)?;

        let mut eng = Self { model, ctx, prefix_tokens: 0, cfg, load_ms: 0 };
        eng.warm_prefix()?;
        eng.load_ms = t0.elapsed().as_millis();
        Ok(eng)
    }

    /// Шаблон ChatML (Qwen). Для Gemma нужен свой — вынести в конфиг модели.
    fn prefix_text() -> String {
        format!("<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>\n")
    }

    /// Считаем системный промпт один раз и держим в KV-кэше (последовательность 0).
    fn warm_prefix(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.ctx.clear_kv_cache();
        let toks = self.model.str_to_token(&Self::prefix_text(), AddBos::Always)?;
        let mut batch = LlamaBatch::new(512, 1);
        for chunk in toks.chunks(512) {
            batch.clear();
            let base = self.prefix_tokens;
            for (i, t) in chunk.iter().enumerate() {
                batch.add(*t, (base + i) as i32, &[0], false)?;
            }
            self.ctx.decode(&mut batch)?;
            self.prefix_tokens += chunk.len();
        }
        Ok(())
    }

    pub fn ask(&mut self, request: &str) -> Result<AskResult, Box<dyn std::error::Error>> {
        let t0 = Instant::now();
        // Отрезаем прошлую просьбу, системный промпт остаётся в кэше.
        self.ctx.clear_kv_cache_seq(Some(0), Some(self.prefix_tokens as u32), None)?;

        let user = format!(
            "<|im_start|>user\nПросьба: {}<|im_end|>\n<|im_start|>assistant\n",
            request.replace("<|", "< |") // не даём пользователю подделать служебные токены
        );
        let toks = self.model.str_to_token(&user, AddBos::Never)?;
        if self.prefix_tokens + toks.len() + self.cfg.max_new_tokens > self.cfg.n_ctx as usize {
            return Err("просьба слишком длинная".into());
        }

        let mut batch = LlamaBatch::new(512, 1);
        let mut pos = self.prefix_tokens;
        for (i, t) in toks.iter().enumerate() {
            batch.add(*t, pos as i32, &[0], i == toks.len() - 1)?;
            pos += 1;
        }
        self.ctx.decode(&mut batch)?;
        let ms_prompt = t0.elapsed().as_millis();

        // Грамматика + greedy: детерминированно, без «фантазии». temp не нужна.
        let mut sampler = LlamaSampler::chain_simple([
            LlamaSampler::grammar(self.model, GRAMMAR, "root")?,
            LlamaSampler::greedy(),
        ]);

        let mut out = Vec::<u8>::new();
        let mut n = 0;
        while n < self.cfg.max_new_tokens {
            let tok = sampler.sample(&self.ctx, batch.n_tokens() - 1); // sample() сам делает accept
            if self.model.is_eog_token(tok) {
                break;
            }
            out.extend(self.model.token_to_piece_bytes(tok, 32, false, None)?);
            n += 1;
            if out.ends_with(b"}") && serde_json::from_slice::<Suggestion>(&out).is_ok() {
                break; // JSON закрыт — дальше не генерируем ни одного лишнего токена
            }
            batch.clear();
            batch.add(tok, pos as i32, &[0], true)?;
            pos += 1;
            self.ctx.decode(&mut batch)?;
        }

        let s: Suggestion = serde_json::from_slice(&out)?;
        let model_risk = match s.risk.as_str() {
            "safe" => Risk::Safe,
            "write" => Risk::Write,
            _ => Risk::Danger,
        };
        let ms_total = t0.elapsed().as_millis();
        Ok(match guard::check(&s.cmd) {
            Verdict::Block(reason) => AskResult::Blocked { cmd: s.cmd, reason },
            Verdict::Allow(r) => AskResult::Ok(Answer {
                cmd: s.cmd,
                explain: s.explain,
                risk: r.max(model_risk),
                ms_prompt,
                ms_total,
                tokens: n,
            }),
        })
    }
}
