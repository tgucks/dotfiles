# Development Guidelines

## Platform

- When working on macOS, always account for BSD tool differences (e.g., `find`, `sed -i`) — do not assume GNU/Linux behavior. Test commands mentally against macOS before suggesting them.
- Default shell is zsh: prefer zsh-compatible syntax for snippets, aliases, and one-liners. Mind differences from bash in arrays, parameter expansion, and `read` flags.

## Tools section

- When an MCP tool covers what you need, use it directly rather than attempting WebFetch/defuddle workarounds. Check available MCP servers first with the appropriate commands.

## Code Style

- **Almost never add comments.** Write self-explanatory code instead - clear names and structure should carry the meaning. Do NOT add comments that restate what the code does, label sections, narrate steps, or explain obvious logic. When in doubt, leave the comment out.
- The only acceptable comments:
  - Documentation comments / docstrings that follow an existing pattern in the codebase (i.e., comparable functions, classes, or modules in that codebase are already documented the same way). Match their style and density; do not introduce docs where the surrounding code has none.
  - A rare inline comment where the code genuinely cannot convey a non-obvious *why* (a workaround, a subtle invariant, a deliberate deviation). Explain the reasoning, never the mechanics.
- Do not add comments to "be helpful" or to explain code back to me. Their absence is the default; their presence must be justified.
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
