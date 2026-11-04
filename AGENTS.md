# Personal agent instructions

Shared by every coding agent I use (Claude Code, Codex, Cursor, …).
Keep it short — facts and rules I'd otherwise repeat. Procedures belong in skills.

## About me
- Name: Andrew
- Timezone: Africa/Cairo (UTC+2)
- <!-- role, main stack, what I usually build -->

## How I like to work
- Be direct and concise; skip long preambles and recaps.
- Ask before destructive or hard-to-undo actions (deleting files, force-push, migrations).
- When requirements are ambiguous, ask one focused question instead of guessing.

## Code
- Match the existing style of the project before introducing new patterns.
- Prefer small, focused changes over large rewrites.
- Run the project's tests/linters before saying something is done.
- <!-- package manager, formatter, language preferences, e.g. "use pnpm, not npm" -->

## Changelog
- On meaningful changes (features, notable improvements, bug fixes, breaking changes), update the project's `CHANGELOG.md` if it has one.
- Keep entries concise and grouped under Added / Changed / Fixed / Removed.

## iOS releases
- In any iOS project, after creating a version tag and before any release or App Store submission, scan the project with the `app-store-review` skill (https://github.com/safaiyeh/app-store-review-skill).
- Report the findings and fix blocking issues before shipping; don't release with unresolved rejection risks unless I say so.

## Git
- Conventional commit messages (`feat:`, `fix:`, `chore:` …).
- Never commit secrets, `.env` files, or credentials.
