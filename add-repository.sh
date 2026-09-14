#!/usr/bin/env bash
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/omarchy-git-monitor-repos.json"
config_dir="${config%/*}"

mkdir -p "$config_dir"

if [[ ! -f "$config" ]]; then
  printf '%s\n' '{"repos":[],"refreshIntervalSec":300}' > "$config"
fi

printf 'GitHub repository to monitor\n'
printf 'Paste an owner/repository name or a GitHub URL.\n'
printf 'Leave empty to finish.\n\n'

while true; do
  read -r -p 'Repository: ' input || break
  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"
  [[ -z "$input" ]] && break

  repo="$(
    INPUT="$input" python3 - <<'PY'
import os
import re
from urllib.parse import urlparse

value = os.environ["INPUT"].strip()
if value.startswith(("https://github.com/", "http://github.com/")):
    parsed = urlparse(value)
    value = parsed.path.strip("/")
    if value.endswith(".git"):
        value = value[:-4]

match = re.fullmatch(r"([^/\s]+)/([^/\s]+)", value)
if not match:
    raise SystemExit("Use owner/repository or a GitHub repository URL.")

print(f"{match.group(1)}/{match.group(2)}")
PY
  )" || {
    printf 'Invalid repository format.\n\n'
    continue
  }

  if ! gh api "repos/$repo" --silent >/dev/null 2>&1; then
    printf 'Repository not found or unavailable: %s\n\n' "$repo"
    continue
  fi

  CONFIG="$config" REPO="$repo" python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["CONFIG"])
data = json.loads(path.read_text(encoding="utf-8"))
repos = data.get("repos", [])
if not isinstance(repos, list):
    repos = []

repo = os.environ["REPO"]
if repo not in repos:
    repos.append(repo)
    data["repos"] = repos
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)
    print(f"Added: {repo}")
else:
    print(f"Already monitored: {repo}")
PY
  printf '\n'
done

printf 'Configuration saved to %s\n' "$config"
printf 'You can close this terminal.\n'
read -r -p 'Press Enter to close...' _
