//! Замер на устройстве: `bench <model.gguf> [threads]`
//! Печатает время загрузки и время/скорость ответа на 10 типовых просьб.
use rtl_ai::engine::{AskResult, Engine, EngineConfig};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let path = args.get(1).ok_or("usage: bench <model.gguf> [threads]")?;
    let threads = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(4);
    let mut eng = Engine::load(path, EngineConfig { threads, ..Default::default() })?;
    println!("load_ms={} threads={threads}", eng.load_ms);

    let reqs = [
        "покажи файлы тут",
        "сколько свободного места",
        "найди все фотки jpg в загрузках",
        "создай папку проекты",
        "удали файл старый.txt",
        "покажи какие процессы жрут память",
        "какой у меня ip адрес",
        "скопируй notes.txt в папку backup",
        "удали вообще всё с телефона",
        "установи питон",
    ];
    for r in reqs {
        match eng.ask(r)? {
            AskResult::Ok(a) => println!(
                "[{:?}] {r} => {}  // {}  prompt={}ms total={}ms tok={} ({:.1} tok/s)",
                a.risk, a.cmd, a.explain, a.ms_prompt, a.ms_total, a.tokens,
                a.tokens as f64 / ((a.ms_total - a.ms_prompt).max(1) as f64 / 1000.0)
            ),
            AskResult::Blocked { cmd, reason } => println!("[BLOCK] {r} => {cmd}  ({reason})"),
        }
    }
    Ok(())
}
