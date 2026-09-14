# OmarchyGitMonitorRepos

An Omarchy 4 bar plugin that monitors unread GitHub notifications for a
selected list of repositories. It complements search tools such as Omni by
providing a visible activity counter and direct links to new issues, pull
requests, reviews, releases, and other GitHub events.

## Requirements

- Omarchy 4
- `gh` (GitHub CLI)
- An authenticated GitHub CLI session

Authenticate once if needed:

```bash
gh auth login
```

The plugin invokes `gh api` with argument arrays. It never stores or embeds a
GitHub token.

## Configuration

Create the configuration directory and copy the example:

```bash
mkdir -p ~/.config/omarchy
cp config.example.json ~/.config/omarchy/omarchy-git-monitor-repos.json
```

Edit the copied file and list repositories as `owner/name`:

```json
{
  "repos": [
    "ciprianotoor/omarchy-media-plugin",
    "ciprianotoor/omarchy-mr-robot-theme"
  ],
  "refreshIntervalSec": 300
}
```

Only unread notifications belonging to the listed repositories are shown.
The GitHub notifications API may include issues, pull requests, requested
reviews, mentions, releases, and workflow-related activity.

## Install

Install directly from GitHub after publishing this repository:

```bash
omarchy plugin add https://github.com/ciprianotoor/omarchy-git-monitor-repos.git \
  --enable
```

Left click opens the panel, right click refreshes it, and clicking an item
opens the corresponding GitHub page. Remove it with:

```bash
omarchy plugin remove io.github.ciprianotoor.omarchy-git-monitor-repos
```

## Validate locally

```bash
omarchy plugin validate .
```

## License

MIT. See [LICENSE](LICENSE).
