# Claude AI Skills

This directory contains Claude AI skills for the termux-agent project.

## Structure
Each skill is organized in its own subdirectory with:
- `manifest.json` - Skill metadata and definitions
- `*.md` - Documentation
- `schemas/` - JSON schemas for tool definitions
- `implementations/` - Optional reference implementations

## Creating a New Skill

1. Create a directory: `skills/your-skill-name/`
2. Add manifest.json with skill metadata
3. Document the skill's functionality
4. Reference in the main agent configuration

## Existing Skills
(Skills will be added here as they are developed)

## Integration
Skills are made available to Claude as tool definitions for:
- Tool calling in Claude models
- Integration with agent workflows
- Custom task automation for termux-agent

For more info on Claude AI skills, see: https://claude.ai/claude-code
