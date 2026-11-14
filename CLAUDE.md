@AGENTS.md

## Claude Code specifics

- **Code lives in files.** Edit `src/` files; Rojo syncs them to Studio. Use the Studio MCP server only for what files cannot reach: inspecting Workspace, building or checking UI in StarterGui, StarterPack, and playtesting.
- **Plan mode** (Shift+Tab) before any change that touches more than 3 files, the data schema, or monetization.
- **Verify with the CLI first** (stylua, selene, luau-lsp, lune). Ask for a Studio playtest only after these pass.
- **Report failures only.** When a check passes, say "passed"; do not paste its output.
- **Delegate noisy work** (long test runs, log digging, doc lookups) to a subagent and keep only the summary here.

## Context hygiene

- Read `docs/GDD.md` by section (grep the heading), never in full.
- Do not read `sourcemap.json`, `Packages/`, or place files.
- Prefer targeted reads (a function, a range) over whole large files.
- When a task is done and the next one is unrelated, tell the user it is a good moment to `/clear`.

# Compact instructions

When compacting, keep: the current task, files changed so far, failing checks with their exact errors, and decisions the user made. Drop: file contents that are already saved, passing check output, and exploration that led nowhere.
