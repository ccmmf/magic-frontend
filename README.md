# magic-frontend

Front end for the MAGiC system. It collects the component repositories as git
submodules and provides one command, `magic-pecan`, for setting up and (in later
phases) running them.

## Quick start

```bash
git clone https://github.com/ccmmf/magic-frontend
cd magic-frontend
module load awscli_v2          # aws CLI >= 1.29
./magic-pecan init             # pull in submodules, check AWS access
./magic-pecan install          # list available environments, newest first
./magic-pecan install latest   # install the newest environment
```

## Components

| Path | Repository | Purpose |
|---|---|---|
| `workflows/` | ccmmf/workflows (branch `main`) | Ensemble workflows (`magic-ensemble`) |
| `downscaling/` | ccmmf/downscaling (branch `develop`) | Downscaling workflow (`magic-downscaling`) |
| `magic-training/` | ccmmf/magic-training (branch `main`) | Training material |
| `tools/` | this repo | Helper scripts used by `magic-pecan` |

Each submodule keeps its own README and CLI and still works on its own.
Submodules are pinned to the commits recorded in this repo.

## Commands

Run `./magic-pecan help` for the full text.

| Command | Action |
|---|---|
| `init [name ...]` | Initialize submodules at their pinned commits (all in `.gitmodules` if no names). Then checks AWS access. |
| `update [name ...]` | Move submodules to the tip of their tracked branch. Changes the pins; review and commit. |
| `install` | List available PEcAn environments, newest first, with last-modified date. No download. |
| `install <VERSION\|latest> [ENV_PATH] [--yes]` | Install an environment. Confirms the default path (`~/.conda/envs/pecan-all`) unless `ENV_PATH` or `--yes` is given. Fails if the path already exists. |

Global option: `--profile <name>` sets the AWS profile for all steps
(default: `$AWS_PROFILE`, else `magic`). Place it before the command.

## Requirements

- `git`
- aws CLI >= 1.29 (`module load awscli_v2` on the cluster) and a configured profile
  (default `magic`). Check with `aws configure list-profiles`.
- `conda` (for `install`)
- `yq` >= 4.53.4 and `Rscript` (for the submodule CLIs)

## Troubleshooting

| Message | Action |
|---|---|
| aws CLI not found / too old | `module load awscli_v2` |
| aws profile not found | Add the profile to the aws configuration, or use `--profile` |
| no connectivity | Check network access from this node |
| path missing or access denied | Confirm the profile has access to the environments bucket |
| environment path already exists | Remove that environment directory and re-run |

## Repository layout

```
magic-pecan        top-level CLI
tools/             helper scripts (environment listing, environment setup)
workflows/         submodule
downscaling/       submodule
magic-training/    submodule
```

## Status

Phase 1 (front-end repo, submodules, setup commands) is in place. Per-component
subcommands (`ensemble`, `downscaling`) are planned for Phase 2. See
https://github.com/orgs/ccmmf/discussions/251.

## License

See `LICENSE`.
