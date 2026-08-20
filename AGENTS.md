# AGENTS.md

## Commit conventions

- Plain English, capitalized titles
- No conventional commit prefixes (no `feat:`, `fix:`, `chore:`)
- No trailing periods
- GPG sign all commits

## Code style

- Nix: 2-space indentation, `with lib;` at the top of each file
- Options: use `mkEnableOption` for feature flags, `mkOption` with proper types
- Submodules: group related options under named submodules (e.g., `kernel`)
- Defaults: provide opinionated defaults that match the Shikanime RKE2
  deployment

## Module design

- All options under `services.knix.*`
- Keep a thin `modules/default.nix` aggregator that imports the submodules
- Keep root options in `modules/knix.nix`
- Keep RKE2 deployment config in `modules/rke2.nix`
- Keep each concern in its own file under `modules/`
- Follow the Catppuccin pattern: `nixosModules.default = import ./modules`

## Stack Workflow

- Install the official GitHub extension once: `gh extension install github/gh-stack`
  (requires GitHub CLI ≥ 2.0; `gh stack` is in public preview and may change).
- Keep one logical change per PR; split large work into a stack of PRs.
- Create a stack: `gh stack init`, then `gh stack add` for each new branch, and
  commit on the active branch. `gh stack view` lists the stack.
- Submit/update: `gh stack submit` (add `--open` to open PRs, `--auto` to skip
  prompts). Resubmit after each change to refresh titles, bodies, and branches.
- Pull down an existing stack: `gh stack checkout <PR_NUMBER>` (also accepts a
  stack number, PR URL, or branch name).
- Rebase onto updated trunk: `gh stack rebase` (cascading), then `gh stack submit`.
- Land a stack: `gh stack merge` (interactive) or
  `gh stack merge <PR_NUMBER> --yes --squash` to merge up to a PR.
- Never `gh pr merge` on a stacked PR — only `gh stack merge` lands stacks.
- Never force-push stack branches; `gh stack` owns the branch pointers.
