<!-- owner: shikanime | zone: internal | purpose: explain the module tree and addon model so a change lands in the right file -->

# Architecture

## Goal

Bootstrap an RKE2 cluster from NixOS with opinionated defaults that match the
Shikanime deployment: dual-stack pod/service networking, host tuning RKE2 and
Longhorn need (bridge netfilter, overlayfs, BBR, conntrack/neighbor limits,
forwarding), and a small option surface under `services.knix.*`.

## Module tree

```text
modules/
  default.nix    # thin aggregator: imports every submodule
  knix.nix       # root options + addon presets (services.knix.*)
  rke2.nix       # RKE2 renderer for charts and manifests
  flux.nix       # Flux CD addon preset
  longhorn.nix   # Longhorn addon + host helper
  traefik.nix    # Traefik addon (Gateway API, Ingress off)
  canal.nix      # Canal CNI meta-plugin (wireguard/vxlan/host-gw)
  coredns.nix    # CoreDNS node caching
  multus.nix     # Multus CNI meta-plugin
  prometheus.nix # Prometheus monitoring
```

`modules/default.nix` is the public surface:
`nixosModules.default = import ./modules`. `knix.nix` owns the root options and
wires the addon presets; `rke2.nix` turns the options into charts/manifests.
Each concern lives in its own file (Catppuccin pattern).

## Addon model

Addons are boolean presets under `services.knix.addons.*` (flux, longhorn,
traefik, canal, coredns, multus, prometheus). Each is independently enableable;
`extraConfig` merges into the rendered Helm chart. An addon off by default (or
on) is intentional — do not flip defaults without a reason.

## Topologies

- **Single node** — `services.knix.role` defaults to `server`; one machine runs
  the control plane and schedules workloads; API at `https://<nodeIP>:9345`.
- **Multi-server HA** — 3 or 5 servers form an etcd quorum; all share one
  `serverAddr` and a `tokenFile` (rotated via sops-nix).
- **Worker-only** — set `services.knix.role = "agent"`; joins via `serverAddr`
  - `tokenFile`, no control plane.
- **Mixed** — common: 3 servers for HA + workers for capacity; front
  `serverAddr` with a VIP or DNS round-robin.
