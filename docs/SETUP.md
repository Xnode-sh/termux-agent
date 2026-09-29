# Setup & Installation

## Prerequisites
- Python 3.8+
- Ollama with at least one model supporting tool-calling (e.g., qwen2.5:7b-instruct)

## Quick Start

### 1. Install Ollama
```bash
# On Linux/macOS
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &

# In Termux (via proot-distro Ubuntu/Debian)
# Follow https://github.com/termux-community/proot-distro for setup
proot-distro login ubuntu
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
```

### 2. Pull a Model
```bash
ollama pull qwen2.5:7b-instruct   # Recommended for tool-calling
# or
ollama pull llama3.1:8b
```

### 3. Clone and Install termux-agent
```bash
git clone https://github.com/Xnode-sh/termux-agent.git
cd termux-agent
python3 -m venv venv
source venv/bin/activate  # or: . venv/Scripts/activate on Windows
pip install -r requirements.txt
```

### 4. Configure (Optional)
```bash
cp config/config.example.yaml termux-agent.yaml
# Edit termux-agent.yaml if needed (model, host, OSINT path, etc.)
```

### 5. Run
```bash
# One-shot query
python3 -m termux_agent.agent "show current directory"

# Interactive REPL
python3 -m termux_agent.agent

# With specific model/host
python3 -m termux_agent.agent --model llama3.1:8b --host http://127.0.0.1:11434

# With auto-confirmation (CAREFUL!)
python3 -m termux_agent.agent --yes "clean __pycache__"
```

## Advanced Setup

### OSINT Integration
To use OSINT tools from [Xnode-sh/Xnode](https://github.com/Xnode-sh/Xnode):

```bash
# Clone Xnode repo alongside or at specific path
git clone https://github.com/Xnode-sh/Xnode.git /path/to/Xnode

# Option 1: Config file
# Edit termux-agent.yaml:
# xnode_path: /path/to/Xnode

# Option 2: Environment variable
export TERMUX_AGENT_XNODE_PATH=/path/to/Xnode

# Now you can use: "lookup email example@test.com", "lookup username admin", etc.
```

### Running Tests
```bash
python3 -m pytest tests/ -v
# or
python3 -m unittest discover -s tests -v
```

## Troubleshooting

### "Connection refused"
- Check Ollama is running: `curl http://127.0.0.1:11434/api/tags`
- Verify TERMUX_AGENT_HOST is correct

### "Model not found"
- Pull the model: `ollama pull qwen2.5:7b-instruct`
- Check available models: `ollama list`

### "Permission denied" on tool execution
- Check file/directory permissions
- Ensure shell_confirmation is working (should ask before executing)
