---
paths:
  - "src/**/*.luau"
  - "tests/**/*.luau"
---

# Luau rules

- `--!strict` first line. Annotate function parameters and return types; shared types come from `Shared/Types.luau`.
- Require shared modules through `ReplicatedStorage.Shared`, server modules through `ServerScriptService.Server`. No relative `script.Parent.Parent...` chains deeper than one level.
- Remotes are created and looked up only through `Shared/Remotes.luau`.
- Server handlers: first line validates input (`typeof`, ranges, ownership), then a per-player rate limit, then logic.
- Client: use `WaitForChild` with a timeout for instances that may stream in. Never assume a part exists.
- Per-frame work uses `RunService.Heartbeat` with delta time, never `while true do task.wait() end` polling loops.
- Track every connection and instance you create and clean them up on player leave or controller teardown.
- Pure logic (Formulas, Config validation, RNG weighting) uses no Roblox APIs so it can run under Lune tests.
- RNG: use one `Random` object per service, seeded on the server. Never use `math.random` for rewards.
