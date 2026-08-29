<!-- owner: shikanime | zone: internal | purpose: the local format/check loop and how to add an addon -->

# Development

## Prerequisites

- Nix with flakes enabled.
- `direnv` (the repo ships `.envrc`); `direnv allow` to load the dev shell.
- This is a `jj` repo. Branch off `main`; never commit to `main` directly.

## Build and check loop

```bash
nix fmt            # treefmt: Nix formatting + markdown lint (80-col)
nix flake check    # evaluate the flake / module options
```

CI (`.github/workflows/`) runs the format/eval pass on every PR. `nix fmt` must
be clean before a PR is reviewable.

## Commit conventions

- Plain English, capitalized titles; no conventional-commit prefixes.
- No trailing periods; GPG sign all commits.

## Code style

- Nix: 2-space indentation, `with lib;` at the top of each file.
- Options: `mkEnableOption` for feature flags, `mkOption` with proper types.
- Group related options under named submodules; provide opinionated defaults
  that match the Shikanime RKE2 deployment.

## Adding an addon

1. Add `modules/<name>.nix` rendering the chart/manifest from its options.
2. Import it from `modules/default.nix` and add the preset to `knix.nix`.
3. Expose `services.knix.addons.<name>.enable` (+ `extraConfig`) under
   `services.knix.*`.
4. `nix fmt`, `nix flake check`, open a PR against `main`.
