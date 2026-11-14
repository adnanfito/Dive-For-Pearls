# Anti-slop rules

Slop = output that looks finished but adds noise, risk, or rework. These rules apply to code, game content, and messages.

## Code

- Smallest diff that solves the task. Do not reformat, rename, or refactor code you were not asked to touch.
- No speculative abstractions, frameworks, or "future-proof" layers. Build what the current task needs.
- Search the repo before writing a helper. Reuse it instead of creating a near-duplicate.
- No stubs presented as done: no `-- TODO: implement`, fake return values, or placeholder logic in finished work. If something is not implemented, say so in the report.
- No dead code and no commented-out code. Git keeps history.
- No magic numbers. Values go in `src/shared/Config`, math goes in `Formulas.luau`.
- `pcall` only around calls that can fail for external reasons (DataStore, MarketplaceService, HttpService, Policy/Ads APIs). Never wrap ordinary logic in `pcall` to hide errors.
- No silent failures. Use `warn()` with context (player, action, values) when something unexpected happens.
- Comments explain why. No banner comments, no emoji, no comments that restate the code.
- Functions stay short and do one thing (roughly under 50 lines). Modules have one responsibility.
- Never invent APIs, properties, or events. Unsure → check the Creator Docs or ask.
- No new dependencies without approval.

## Game content

- Only build mechanics that are in `docs/GDD.md`. A new mechanic or system needs approval first.
- Player-facing text: short, simple English a 7-year-old can read. Prefer icons over words.
- No copyrighted characters, music, logos, or assets from other games.
- Never change balancing numbers, prices, or odds on your own. Propose the change and the reason.

## Messages to the user

- Final report, at most 10 lines: files changed, how it was verified, manual playtest steps, open issues.
- No praise, no "Great question", no restating the task, no long summaries of code the user can read.
- Never claim something was tested if the check was not actually run. Say what was not verified.
- When blocked on a design, balancing, or monetization decision, ask one specific question instead of guessing.
