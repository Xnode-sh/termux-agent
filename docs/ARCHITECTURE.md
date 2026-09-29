# Architecture

## Overview
termux-agent is a local LLM-based tool-calling agent designed for Termux/proot environments on Android.

## Components

### Core Modules
- **agent.py** - Main REPL and conversation loop orchestrator
- **config.py** - Configuration loader (YAML + environment variables)
- **llm_client.py** - Ollama client for LLM communication
- **tools.py** - Tool definitions and dispatcher

### Tool Calling Flow
1. User sends a query
2. Agent sends query + tool schemas to Ollama
3. Model responds with either:
   - Final answer (no tool calls) → return to user
   - Tool call request → execute tool and loop back
4. Continue until max_steps reached or model provides final answer

### Tools
- **run_shell** - Execute shell commands (requires confirmation)
- **read_file** - Read text files (max 20KB)
- **write_file** - Write files, create directories (confirmation on overwrite)
- **list_dir** - List directory contents
- **osint_lookup** - Call OSINT tools from Xnode-sh/Xnode

## Configuration
Configuration is loaded from:
1. `termux-agent.yaml` in current directory (if exists)
2. Environment variables (TERMUX_AGENT_*)
3. Hardcoded defaults

## Safety
- `run_shell` and `write_file` require confirmation by default
- Use `--yes` flag or `auto_yes: true` only with trusted models/prompts
- Run in Termux/proot sandbox, not on bare system with sensitive data
