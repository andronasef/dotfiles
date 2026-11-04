#!/usr/bin/env bash
# Sync this repo into your home folder:
#   - links every file in home/ to the same path under ~ (a folder holding a
#     .dirlink file is linked as a whole folder instead)
#   - links CLAUDE.md, AGENTS.md, agents/*.md, rules/*.md
#   - installs/updates every skill & plugin listed in sources.txt
#   - removes skills that were dropped from sources.txt
# Safe to run as often as you like.
#
# Usage: ./sync.sh [--no-plugins] [--no-skills]
# Env:   CLAUDE_HOME (default ~/.claude)   DOTFILES_CACHE (default ~/.cache/dotfiles)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CACHE="${DOTFILES_CACHE:-$HOME/.cache/dotfiles}/sources"
SOURCES="${DOTFILES_SOURCES:-$REPO_DIR/sources.txt}"
DO_PLUGINS=1; DO_SKILLS=1
for a in "$@"; do case "$a" in
  --no-plugins) DO_PLUGINS=0 ;;
  --no-skills)  DO_SKILLS=0; DO_PLUGINS=0 ;;
  *) echo "unknown option: $a" >&2; exit 2 ;;
esac; done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WANTED="$TMP/wanted"; FETCHED="$TMP/fetched"; FAILED="$TMP/failed"
: > "$WANTED"; : > "$FETCHED"; : > "$FAILED"
ERRORS=0

c_ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
c_warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
c_err()  { printf '  \033[31m✗\033[0m %s\n' "$*"; ERRORS=$((ERRORS+1)); }
head_()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

mkdir -p "$CLAUDE_HOME/skills" "$CLAUDE_HOME/agents" "$CLAUDE_HOME/rules" "$CACHE"

# link SRC DEST — symlink, backing up a real file that's in the way
link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    [ "$(readlink "$dest")" = "$src" ] && return 0
    rm "$dest"
  elif [ -e "$dest" ]; then
    mv "$dest" "$dest.bak-$(date +%Y%m%d%H%M%S)"
    c_warn "backed up existing $(basename "$dest")"
  fi
  ln -s "$src" "$dest"
}

# remove symlinks in DIR that point under PREFIX but whose target is gone / unwanted
prune_dir() {
  local dir="$1" prefix="$2" wanted_file="${3:-}" f t
  for f in "$dir"/* "$dir"/.[!.]*; do
    [ -L "$f" ] || continue
    t="$(readlink "$f")"
    case "$t" in "$prefix"*) ;; *) continue ;; esac
    if [ ! -e "$f" ] || { [ -n "$wanted_file" ] && ! grep -qxF "$f" "$wanted_file"; }; then
      rm "$f"; c_warn "removed $(basename "$f")"
    fi
  done
}

# ── 0. Dotfiles (home/ → ~) ─────────────────────────────────
head_ "Dotfiles"
HOME_SRC="$REPO_DIR/home"
if [ -d "$HOME_SRC" ]; then
  DIRLINKS="$(find "$HOME_SRC" -name .dirlink -exec dirname {} \;)"
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    rel="${d#$HOME_SRC/}"; mkdir -p "$(dirname "$HOME/$rel")"
    link "$d" "$HOME/$rel" && c_ok "~/$rel/"
  done <<< "$DIRLINKS"
  while IFS= read -r f; do
    rel="${f#$HOME_SRC/}"
    while IFS= read -r d; do [ -n "$d" ] && case "$f" in "$d"/*) continue 2 ;; esac; done <<< "$DIRLINKS"
    mkdir -p "$(dirname "$HOME/$rel")"
    link "$f" "$HOME/$rel" && c_ok "~/$rel"
  done < <(find "$HOME_SRC" -type f ! -name .DS_Store | sort)
fi

# ── 1. Instruction files ────────────────────────────────────
head_ "Instructions"
link "$REPO_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md" && c_ok "~/.claude/CLAUDE.md"
link "$REPO_DIR/AGENTS.md" "$CLAUDE_HOME/AGENTS.md" && c_ok "~/.claude/AGENTS.md"
for d in .codex .agents; do
  [ -d "$HOME/$d" ] && link "$REPO_DIR/AGENTS.md" "$HOME/$d/AGENTS.md" && c_ok "~/$d/AGENTS.md"
done

# ── 2. Agents & rules ───────────────────────────────────────
head_ "Agents & rules"
for kind in agents rules; do
  for f in "$REPO_DIR/$kind"/*.md; do
    [ -e "$f" ] || continue
    link "$f" "$CLAUDE_HOME/$kind/$(basename "$f")" && c_ok "$kind/$(basename "$f")"
  done
  prune_dir "$CLAUDE_HOME/$kind" "$REPO_DIR/$kind/"
done

[ "$DO_SKILLS" = 1 ] || { echo; echo "Done (skills skipped)."; exit 0; }

# ── 3. Sources ──────────────────────────────────────────────
to_url() {  # owner/repo → GitHub https URL; anything else passes through
  case "$1" in
    http://*|https://*|git@*|ssh://*|file://*|/*) echo "$1" ;;
    *) echo "https://github.com/$1.git" ;;
  esac
}

# fetch SOURCE → prints local checkout dir (fetches once per run)
fetch() {
  local spec="$1" repo ref url key dir
  repo="${spec%%#*}"; ref=""; [ "$spec" != "$repo" ] && ref="${spec#*#}"
  url="$(to_url "$repo")"
  key="$(printf '%s' "$repo${ref:+@$ref}" | sed -E 's#^[a-z]+://##; s#\.git$##; s#[^A-Za-z0-9._-]+#__#g')"
  dir="$CACHE/$key"
  grep -qxF "$dir" "$FAILED" && return 1
  if ! grep -qxF "$dir" "$FETCHED"; then
    if [ -d "$dir/.git" ]; then
      git -C "$dir" fetch --quiet --depth 1 origin "${ref:-HEAD}" >&2 \
        && git -C "$dir" reset --quiet --hard FETCH_HEAD >&2 \
        || { echo "$dir" >> "$FAILED"; return 1; }
    else
      rm -rf "$dir"
      git clone --quiet --depth 1 ${ref:+--branch "$ref"} "$url" "$dir" >&2 \
        || { echo "$dir" >> "$FAILED"; return 1; }
    fi
    echo "$dir" >> "$FETCHED"
  fi
  echo "$dir"
}

install_skill() {  # SKILL_DIR
  local src="$1" name dest
  src="${src%/.}"; name="$(basename "$src")"
  # repo-root skill (target "."): take the name from SKILL.md frontmatter
  [ "$(dirname "$src")" = "$CACHE" ] && name="$(sed -n 's/^name:[[:space:]]*//p' "$src/SKILL.md" | head -1 | tr -d "\"'")"
  dest="$CLAUDE_HOME/skills/$name"
  if [ ! -f "$src/SKILL.md" ]; then c_err "no SKILL.md in ${src#$CACHE/}"; return; fi
  if grep -qxF "$dest" "$WANTED"; then c_warn "skipped duplicate '$name' (${src#$CACHE/})"; return; fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    c_err "skills/$name exists and isn't managed by dotfiles — rename or remove it"; return
  fi
  link "$src" "$dest"; echo "$dest" >> "$WANTED"
  c_ok "$name  ($(git -C "$(dirname "$src")" rev-parse --short HEAD 2>/dev/null || echo '?'))"
}

PLUGIN_LIST=""
install_plugin() {  # SOURCE PLUGIN@MARKETPLACE
  local spec="$1" id="$2" mkt="${2#*@}"
  if [ "$DO_PLUGINS" = 0 ]; then c_warn "skipped plugin $id (--no-plugins)"; return; fi
  if ! command -v claude >/dev/null 2>&1; then c_err "claude CLI not found — can't install $id"; return; fi
  if [ "$id" = "$mkt" ]; then c_err "plugin target must be name@marketplace (got '$id')"; return; fi
  if [ -z "$PLUGIN_LIST" ]; then PLUGIN_LIST="$(claude plugin list 2>/dev/null || true)"; [ -n "$PLUGIN_LIST" ] || PLUGIN_LIST=" "; fi
  if ! claude plugin marketplace list 2>/dev/null | grep -q -- "$mkt"; then
    claude plugin marketplace add "$spec" >/dev/null 2>&1 || { c_err "couldn't add marketplace $spec"; return; }
  elif ! grep -qxF "$mkt" "$TMP/mkts" 2>/dev/null; then
    claude plugin marketplace update "$mkt" >/dev/null 2>&1 || true
    echo "$mkt" >> "$TMP/mkts"
  fi
  if printf '%s' "$PLUGIN_LIST" | grep -q -- "$id"; then
    claude plugin update "$id" >/dev/null 2>&1 && c_ok "$id (updated)" || c_err "update failed: $id"
  else
    claude plugin install "$id" >/dev/null 2>&1 && c_ok "$id (installed)" || c_err "install failed: $id"
  fi
}

head_ "Skills & plugins  (from sources.txt)"
while read -r kind src target _rest || [ -n "${kind:-}" ]; do
  case "${kind:-}" in ''|\#*) continue ;; esac
  if [ -z "${src:-}" ] || [ -z "${target:-}" ]; then c_err "bad line: $kind $src $target"; continue; fi
  case "$kind" in
    skill)
      dir="$(fetch "$src")" || { c_err "can't fetch $src"; continue; }
      install_skill "$dir/${target%/}" ;;  # target "." = skill at repo root
    skills)
      dir="$(fetch "$src")" || { c_err "can't fetch $src"; continue; }
      found=0
      # every SKILL.md under target, any depth (target "." = whole repo)
      while IFS= read -r s; do
        install_skill "$(dirname "$s")"; found=1
      done < <(find "$dir/${target%/}" -name .git -prune -o -name SKILL.md -print | sort)
      [ "$found" = 1 ] || c_err "no skills found under $src/$target" ;;
    plugin)
      install_plugin "$src" "$target" ;;
    agy-plugin)  # Antigravity: git clone in ~/.gemini/config/plugins/<name>
      if [ "$DO_PLUGINS" = 0 ]; then c_warn "skipped agy plugin $target (--no-plugins)"; continue; fi
      d="$HOME/.gemini/config/plugins/$target"
      if [ -d "$d/.git" ]; then
        git -C "$d" pull --quiet --ff-only && c_ok "agy $target (updated)" || c_err "agy update failed: $target"
      elif [ -e "$d" ]; then
        c_err "agy plugin $target exists but isn't a git clone"
      else
        mkdir -p "$(dirname "$d")"
        git clone --quiet "$(to_url "$src")" "$d" && c_ok "agy $target (installed)" || c_err "agy install failed: $target"
      fi ;;
    *)
      c_err "unknown kind '$kind' (use skill, skills, plugin or agy-plugin)" ;;
  esac
done < "$SOURCES"

# ── 4. Prune skills no longer listed ────────────────────────
prune_dir "$CLAUDE_HOME/skills" "$CACHE/" "$WANTED"

echo
if [ "$ERRORS" -gt 0 ]; then echo "Done with $ERRORS problem(s)."; exit 1; fi
echo "Done. Start a new Claude Code session (or run /reload-skills) to pick up changes."
