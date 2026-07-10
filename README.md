# Claude Code Documentation Mirror

[![Last Update](https://img.shields.io/github/last-commit/bartvanhoey/claude-code-docs/main.svg?label=docs%20updated)](https://github.com/bartvanhoey/claude-code-docs/commits/main)
[![Platform](https://img.shields.io/badge/platform-Windows-blue)](https://github.com/bartvanhoey/claude-code-docs)
[![Dependabot Updates](https://github.com/bartvanhoey/claude-code-docs/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/bartvanhoey/claude-code-docs/actions/workflows/dependabot/dependabot-updates)
[![Create Release](https://github.com/bartvanhoey/claude-code-docs/actions/workflows/release.yml/badge.svg)](https://github.com/bartvanhoey/claude-code-docs/actions/workflows/release.yml)

A local, auto-updating mirror of the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code/), exposed to Claude as a `/docs` slash command. No more fetching from the web — docs sync from GitHub every 3 hours and Claude reads them straight off disk.

**Windows only** — this is a fork of [claude-code-docs](https://github.com/ericbuess/claude-code-docs) by [@EricBuess](https://github.com/EricBuess), rebuilt specifically for Windows/Git Bash. macOS/Linux support from the original has been removed; use the upstream repo on those platforms.

## Why

- **Fast** — reads local files instead of hitting the web
- **Fresh** — GitHub Actions syncs docs every 3 hours
- **Searchable** — ask natural-language questions across all docs
- **Changelog access** — `/docs changelog` pulls official release notes

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bartvanhoey/claude-code-docs/main/install.sh | bash
```

Requires Windows with [Git for Windows](https://git-scm.com/download/win) (provides Git Bash, `git`, and `curl`). `jq` is downloaded automatically — no manual setup needed.

This installs to `~/.claude-code-docs`, adds the `/docs` command, and sets up a hook that pulls the latest docs automatically when you use it. Restart Claude Code afterward.

Run the same command any time to update or migrate an existing install.

## Usage

```bash
/docs hooks              # read hooks documentation
/docs mcp                # read MCP documentation
/docs -t                 # check sync status with GitHub
/docs what's new         # see recent doc changes
/docs changelog          # read official Claude Code release notes
/docs uninstall          # remove everything
```

Natural-language queries work too:

```bash
/docs what environment variables exist and how do I use them?
/docs find all mentions of authentication
```

Want a different command name? Rename `~/.claude/commands/docs.md` to whatever you like — the filename is the command.

## Uninstall

```bash
/docs uninstall
```

or

```bash
~/.claude-code-docs/uninstall.sh
```

See [UNINSTALL.md](UNINSTALL.md) for manual steps.

## Security notes

- The install hook only runs `git pull`, scoped to the docs directory — nothing else, nothing external.
- The `curl | bash` installer has no checksum/signature verification (standard tradeoff for one-liner installs). For a safer path, clone manually and review `install.sh` before running it:

  ```bash
  git clone https://github.com/bartvanhoey/claude-code-docs.git ~/.claude-code-docs
  cd ~/.claude-code-docs
  bash install.sh
  ```

## Contributing

Bug reports and ideas welcome — [open an issue](https://github.com/bartvanhoey/claude-code-docs/issues).

## License

Documentation content belongs to Anthropic. This mirror tool is open source.
