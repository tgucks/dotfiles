# Development Guidelines

## Platform

- When working on macOS, always account for BSD tool differences (e.g., `find`, `sed -i`) — do not assume GNU/Linux behavior. Test commands mentally against macOS before suggesting them.
- Default shell is zsh: prefer zsh-compatible syntax for snippets, aliases, and one-liners. Mind differences from bash in arrays, parameter expansion, and `read` flags.

## Tools section

- When using MCP tools (e.g., Atlassian MCP for Confluence/Jira), use the MCP tool directly rather than attempting WebFetch/defuddle workarounds. Check available MCP servers first with the appropriate commands.

## Code Style

- Write self-explanatory code instead of adding comments. Only comment when the code alone cannot convey the reasoning or decision behind it.
- Never use "Em Dashes". Just use regular hyphens `-` instead.

## Important Reminders

**NEVER**:
- Use `--no-verify` to bypass commit hooks
- Disable tests instead of fixing them
- Commit code that doesn't compile
- Make assumptions - verify with existing code

**ALWAYS**:
- Commit working code incrementally
- Update plan documentation as you go
- Learn from existing implementations
- Stop after 3 failed attempts and reassess
- When editing dotfiles, update the chezmoi source in `~/dotfiles/` and run `chezmoi apply` — never edit targets directly
