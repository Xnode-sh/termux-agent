# Security

## Important
This agent has shell access to your device. Treat it with caution.

## Safety Features
- `run_shell` and `write_file` require confirmation by default
- Use `--yes`/`auto_yes: true` only for trusted, automated scenarios
- Protection against infinite loops via `max_steps` limit

## Best Practices
1. Keep `auto_yes` disabled when using untrusted models or custom prompts
2. Run in Termux/proot sandbox, not on bare system with sensitive data
3. Review tool calls before confirming them
4. Monitor the LLM's behavior for unexpected commands
5. Use resource-constrained models for untrusted scenarios

## OSINT Integration
When using `osint_lookup` (Xnode-sh/Xnode integration):
- Specify `xnode_path` in config or `TERMUX_AGENT_XNODE_PATH` env var
- External API calls from OSINT tools may have privacy implications
- Review OSINT tool code before running automated lookups

## Sandboxing
Recommended setup for security-conscious usage:
- Termux app on Android (isolated from system)
- proot-distro for additional isolation
- Minimal permissions granted to Termux app
- No access to sensitive files outside sandbox
