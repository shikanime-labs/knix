<!-- owner: shikanime | zone: internal | purpose: how to consume, pick a topology, and protect the repo without surprises -->

# Runbook

This repo is a module library, not a deployable service. "Operations" means
keeping the RKE2 presets coherent across the fleet's NixOS hosts.

## Consuming the module

In a `nixosConfiguration`, import the module and flip the main switch:

```nix
modules = [ knix.nixosModules.default { services.knix.enable = true; } ];
```

Enable addons independently (`services.knix.addons.longhorn.enable = true`,
`services.knix.addons.flux.enable = true`, ...). Traefik configures Gateway API
and disables Ingress by default.

## Choosing a topology

- Single node: leave `role` at `server`; good for homelab/CI.
- HA: generate a token (`openssl rand -hex 32`), store it with sops-nix as
  `rke2-token`, and set `tokenFile = config.sops.secrets.rke2-token.path` plus a
  shared `serverAddr` on every server.
- Workers: set `role = "agent"` and point `serverAddr` at the VIP.

## Releasing

There is no tag or publish step — consumers pin `github:shikanime-studio/knix`
by rev through their flake. A change is "released" the moment it merges to
`main`; downstream flake updates pull it in.

## Branch protection

`main` requires one approving review, linear history, signed commits, and
squash+rebase only. PRs are the merge path; direct pushes are rejected.

## CI

`.github/workflows/` runs the format/eval pass on every PR, plus Renovate for
flake input bumps. Land bumps on `main` via squash+rebase (see `AGENTS.md`).
