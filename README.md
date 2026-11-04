# dotfiles

My Mac setup in one repo: AI instructions (`AGENTS.md`, `CLAUDE.md`), subagents, rules, a **list** of skill and plugin repos, app configs, and a Brewfile.
Skills aren't copied in here. `sources.txt` points at their upstream repos, and `sync.sh` pulls the latest versions.

```
dotfiles/
├── AGENTS.md     # instructions every agent reads (Claude Code, Codex, Antigravity…)
├── CLAUDE.md     # imports AGENTS.md, plus Claude-only extras
├── sources.txt   # the list of skill / plugin repos
├── sync.sh       # links + installs everything
├── Brewfile      # brew bundle
├── agents/       # my subagents      → ~/.claude/agents/
├── rules/        # always-on rules   → ~/.claude/rules/
├── mac/          # mirrors ~ on macOS  (zsh, Zed, VS Code, Karabiner, gh, Claude/Codex/Gemini settings…)
└── windows/      # mirrors %USERPROFILE% on Windows (empty for now)
```

## Setup (new Mac)

```bash
git clone https://github.com/andronasef/dotfiles.git ~/Documents/Work/Dev/Projects/Other/dotfiles
cd ~/Documents/Work/Dev/Projects/Other/dotfiles
brew bundle
./sync.sh
```

## Daily use

| I want to… | Do this |
|---|---|
| Update all skills and plugins | `./sync.sh` |
| Only relink dotfiles and instructions | `./sync.sh --no-skills` |
| Skip plugin installs | `./sync.sh --no-plugins` |
| Add a skill repo | add a line to `sources.txt`, run `./sync.sh` |
| Remove one | delete its line, run `./sync.sh` (its skills get unlinked) |
| Pin a version | `owner/repo#v1.2.0` in `sources.txt` |
| Save a new app config | copy it under `mac/` at the same path, run `./sync.sh` |
| Refresh the Brewfile | `brew bundle dump --force` |

### `sources.txt` format

```
skills      anthropics/skills                   skills          # every SKILL.md under a folder, any depth ("." = whole repo)
skill       owner/repo                          path/to/skill   # one skill folder
plugin      anthropics/claude-plugins-official  expo@claude-plugins-official   # Claude Code plugin
agy-plugin  obra/superpowers                    superpowers     # Antigravity plugin (git clone)
```

Sources can be GitHub `owner/repo` or any git URL. Codex plugins live in `mac/.codex/config.toml`.

## What `sync.sh` does

1. Symlinks every file in `mac/` to the same path under `~`. A folder holding a `.dirlink` file is linked as a whole.
2. Symlinks `CLAUDE.md` and `AGENTS.md` into `~/.claude/` (and `AGENTS.md` into `~/.codex/` and `~/.agents/`).
3. Symlinks `agents/*.md` and `rules/*.md` into `~/.claude/`.
4. Shallow-clones each source into `~/.cache/dotfiles/` and links every skill into `~/.claude/skills/<name>`. If two repos ship the same skill name, the first one listed wins.
5. Installs or updates Claude Code and Antigravity plugins.
6. Unlinks skills that are no longer listed.

A real file in the way is kept as `<name>.bak-<timestamp>`. Skills you made by hand in `~/.claude/skills/` are never touched.

## Never commit

Logins and keys stay out of this repo: `~/.claude.json`, `~/.gemini/oauth_creds.json` and other token files, `~/.ssh` keys, `~/.config/gh/hosts.yml`, shell history, `.env` files.
Because the configs in `mac/` are symlinks, apps write straight into this repo. Check `git diff` before every commit.
