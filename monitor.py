#!/usr/bin/env python3
"""Read GitHub repository events through the user's authenticated gh CLI."""

import json
import subprocess
import sys
from pathlib import Path


STATE_PATH = Path.home() / ".cache/omarchy-git-monitor-repos/state.json"


def gh_events(repo: str) -> list[dict]:
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/events", "--jq", "."],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def main() -> int:
    config_path = Path.home() / ".config/omarchy/omarchy-git-monitor-repos.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    repos = [str(repo).strip() for repo in config.get("repos", [])]
    repos = [repo for repo in repos if repo.count("/") == 1]

    old_state = {}
    if STATE_PATH.exists():
        old_state = json.loads(STATE_PATH.read_text(encoding="utf-8"))

    activities = []
    new_count = 0
    next_state = {}
    for repo in repos:
        events = gh_events(repo)
        previous_ids = old_state.get(repo, [])
        if isinstance(previous_ids, str):
            previous_ids = [previous_ids] if previous_ids else []
        previous_ids = {str(event_id) for event_id in previous_ids}
        first_run = not previous_ids
        current_ids = []
        for event in events[:10]:
            event_id = str(event.get("id", ""))
            if event_id:
                current_ids.append(event_id)
            if event_id and not first_run and event_id not in previous_ids:
                new_count += 1
            payload = event.get("payload", {})
            activities.append(
                {
                    "repo": repo,
                    "type": str(event.get("type", "GitHub activity")).removesuffix(
                        "Event"
                    ),
                    "title": str(
                        payload.get("ref")
                        or payload.get("action")
                        or event.get("type", "GitHub activity")
                    ),
                    "url": f"https://github.com/{repo}",
                    "id": event_id,
                    "attention": event.get("type")
                    in {"IssuesEvent", "PullRequestReviewEvent", "IssueCommentEvent"},
                }
            )
        if current_ids:
            next_state[repo] = list(dict.fromkeys(current_ids + list(previous_ids)))[:100]
        elif previous_ids:
            next_state[repo] = list(previous_ids)[:100]

    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(next_state), encoding="utf-8")
    print(json.dumps({"activities": activities[:20], "newCount": new_count, "firstRun": first_run}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
