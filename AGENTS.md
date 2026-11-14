# Dive for Pearls — Agent Guide

Roblox game. Primary players: kids 7–12, mobile-first. Secondary: 13–18.
Full design lives in `docs/GDD.md`. Read only the section you need (grep the heading), never the whole file.

Core loop: AFK in Pressure Chamber raises Depth Limit → dive deeper zones → collect shells → shells ripen in Aquarium → open shell (pearl gacha) → equip pearl (multiplier), display it (coins/sec) or sell it → upgrade → repeat.

## Stack and commands

- Luau, Rojo (file sync), Roblox Studio built-in MCP server, Rokit for tool versions.
- Format: `stylua src tests`
- Lint: `selene src`
- Type check (first time only, download Roblox types: `curl -L -o globalTypes.d.luau https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau`):
  `rojo sourcemap default.project.json -o sourcemap.json` then
  `luau-lsp analyze --platform=roblox --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json --ignore="**/vendor/**" src`
  (`vendor/` holds pinned third-party code such as ProfileStore; it is not ours to fix, so its diagnostics are ignored.)
- Pure-logic tests (no Studio): `lune run tests/run`
- Sync to Studio: `rojo serve` (human runs it; do not start long-running servers yourself)

## Repo layout

```
src/
  shared/            -> ReplicatedStorage.Shared
    Config/          Zones, Pearls, Shells, Pets, Eggs, Quests, Events, Products (data only)
    Formulas.luau    every balancing formula, pure functions, no Roblox APIs
    Types.luau       shared types
    Remotes.luau     single registry of RemoteEvents/RemoteFunctions
  server/            -> ServerScriptService.Server
    Bootstrap.server.luau
    Services/        DataService, DiveService, ShellService, PressureService, PetService,
                     EconomyService, QuestService, EventService, MonetizationService, AnalyticsService
  client/            -> StarterPlayerScripts.Client
    Bootstrap.client.luau
    Controllers/     one controller per domain (UI, Dive, Aquarium, Pressure, Pets, ...)
tests/               Lune specs for Formulas and Config validation
docs/GDD.md          design source of truth
```

## Architecture rules (non-negotiable)

1. **Data-driven content.** Zones, pearls, shells, pets, eggs, quests, events live in `src/shared/Config`. Adding content = adding a row, not new code paths.
2. **One formula module.** All balancing math lives in `Formulas.luau`. No magic numbers anywhere else.
3. **Server-authoritative.** RNG, currency, tickets, rewards, purchases, depth gain are computed on the server only. The client renders and sends requests.
4. **Validate every remote** on the server: argument types, ranges, ownership, rate limit. Never trust client values.
5. **Services own domains.** One Service per domain on the server, one Controller per domain on the client. Cross-domain calls go through explicit module APIs, never `_G` or shared globals.
6. **One DataService.** Session-locked player data with a versioned schema and migrations. No other module touches DataStores.
7. **Monetization policy.**
   - Paid random items (paid egg tickets) show numeric odds before purchase and are gated with PolicyService.
   - Pets are never tradeable. Only pearls are tradeable.
   - Every shell and egg always yields an item. No losing outcome.
   - No casino wording (bet, jackpot, chips, gamble).
   - Rewarded ads only through Roblox's native API; under-13 players get a free equivalent.
8. **Caps.** Multipliers add (1 + sum of bonuses), never multiply together. Respect the caps defined in Config.

## Code conventions

- `--!strict` at the top of every module.
- File suffixes: `.server.luau`, `.client.luau`, `.luau` for modules.
- PascalCase for modules, services, types; camelCase for locals and functions; UPPER_SNAKE for constants.
- Use `task.*` (`task.wait`, `task.spawn`, `task.delay`). Never `wait`, `spawn`, `delay`.
- Comments explain why, not what.

## Definition of done

- `stylua`, `selene`, and `luau-lsp analyze` report no errors on touched files.
- Lune tests pass for any touched pure module.
- The final message lists: files changed, how it was verified, manual playtest steps (if any), open issues.

## Workflow

- Work in small, testable steps. One feature per task.
- For changes touching more than 3 files or the data schema: propose a plan first, then implement.
- Commit after each working step with a conventional commit message (`feat:`, `fix:`, `refactor:`, `chore:`).
- Follow `.claude/rules/anti-slop.md`. It applies to every agent, not only Claude.

## Never

- Edit or read place files (`*.rbxl`, `*.rbxlx`).
- Change balancing values in Config, product IDs, or prices without explicit approval.
- Add third-party packages without asking.
- Invent Roblox APIs. If unsure an API exists, check the Roblox Creator Docs or say so.
