# Configuration

## config.example.yaml
Template configuration file with all available options.

## Environment Variables
All config keys can be overridden by environment variables with `TERMUX_AGENT_` prefix:
- `TERMUX_AGENT_MODEL` - LLM model name (default: qwen2.5:7b-instruct)
- `TERMUX_AGENT_HOST` - Ollama server URL (default: http://127.0.0.1:11434)
- `TERMUX_AGENT_XNODE_PATH` - Path to Xnode-sh/Xnode repository (for OSINT tools)
- `TERMUX_AGENT_AUTO_YES` - Auto-confirm shell/file operations (default: 0)

## Priority
Environment variables override config file, which overrides defaults.

## Usage
```bash
# Use config file
cp config/config.example.yaml termux-agent.yaml
# ... edit termux-agent.yaml ...
python3 -m termux_agent.agent

# Or override via environment
export TERMUX_AGENT_MODEL=llama3.1:8b
python3 -m termux_agent.agent

# Or via command-line args
python3 -m termux_agent.agent --model llama3.1:8b --host http://127.0.0.1:11434
```
