# Development Guidelines

## Platform

- When working on macOS, always account for BSD tool differences (e.g., `find`, `sed -i`) — do not assume GNU/Linux behavior. Test commands mentally against macOS before suggesting them.

## Tools section

- When using MCP tools (e.g., Atlassian MCP for Confluence/Jira), use the MCP tool directly rather than attempting WebFetch/defuddle workarounds. Check available MCP servers first with the appropriate commands.

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
