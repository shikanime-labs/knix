<!-- owner: Automata | zone: technical | purpose: Canonical technical index for knix, the RKE2 NixOS module set -->
# Knix

An opinionated NixOS module set for bootstrapping an RKE2 cluster. It ships a
default cluster layout &mdash; an RKE2 server with pod/service networking defaults
for IPv4 and IPv6, optional Flux CD GitOps and Longhorn storage &mdash; behind a
small option surface under `services.knix.*`, exported as
`knix.nixosModules.default` from a flake.

## Topology patterns

All layouts import `knix.nixosModules.default` and differ only in
`services.knix` settings; the cluster API is RKE2's `:9345` endpoint.

- Single node &mdash; one machine is server and worker (`role = "server"` by
  default). Good for homelabs, CI runners, small deployments.
- Multi-server HA &mdash; three or five servers form an etcd quorum. Share one
  token (`openssl rand -hex 32`) via sops-nix `tokenFile` and one `serverAddr`;
  each node gets its own `nodeIP`. The first server initializes etcd, the rest
  join as voters.
- Worker-only &mdash; `role = "agent"`: same `tokenFile`, joins via
  `serverAddr`, runs no control plane or etcd.
- Mixed &mdash; three server/etcd voters plus workers; point `serverAddr` at a
  virtual IP or DNS round-robin.

Knix also applies the host tuning RKE2/Longhorn need: bridge netfilter,
overlayfs, BBR, conntrack/neighbor-table limits, and IPv4/IPv6 forwarding,
including an IPv6 egress firewall that rejects global IPv6 on the cluster
interface with a UDP/53 carve-out for resolvers.

## Modules

Everything is imported through `modules/default.nix`; all options live under
`services.knix`.

- `knix.nix` &mdash; top level: `enable`, `role`, networking (`clusterCidr`,
  `clusterCidrIPv6`, `serviceCidr`, `nodeCidrMaskSize`,
  `nodeCidrMaskSizeIPv6`, `interface`, `nodeIP`), join settings (`serverAddr`,
  `tokenFile`), `labels`, `charts`, `manifests`, and `extraConfig` RKE2 flags.
- `rke2.nix` &mdash; RKE2 server/agent wiring: `mkExtraFlags`, auto-deploy chart
  rendering on the server role, node labels, and host tuning.
- `canal.nix` &mdash; Canal CNI, on by default; `backend` is `host-gw`, `vxlan`,
  or `wireguard` (default). `host-gw` suits same-LAN, `vxlan` multi-subnet.
- `multus.nix`, `coredns.nix` &mdash; Multus CNI and CoreDNS node caching, on by
  default, with `extraConfig` merged into their `HelmChartConfig`. CoreDNS also
  exposes metrics via a scrape job contributed through `extraScrapeConfigs`.
- `flux.nix` &mdash; Flux CD GitOps, on by default; sync passed through
  `addons.flux.instance.extraConfig`.
- `longhorn.nix` &mdash; persistent storage, on by default; `mountRoot`
  (default `/mnt`) scanned for extra disks,
  `storageReservedPercentageForDefaultDisk` default 30.
- `prometheus.nix` &mdash; monitoring, on by default; exposes control-plane and
  built-in etcd/kube-proxy scrape jobs on the server role, with
  `extraScrapeConfigs` for additional jobs.

## Common settings

`services.knix.enable` is the main switch. Typical overrides: `nodeIP`,
`serverAddr`, `tokenFile`, `clusterCidr`, `clusterCidrIPv6`, `serviceCidr`,
`interface`, and `labels`. Flux, Longhorn, and monitoring can each be enabled
independently.

## Repository layout

- `modules/` &mdash; `default`, `knix`, `rke2`, `flux`, `longhorn`, `canal`,
  `coredns`, `multus`, `prometheus`
- `flake.nix` / `flake.lock` &mdash; flake entry point and pinned inputs
- `docs/` &mdash; this canonical index
- `README.md` &mdash; human-facing overview with the full option tables

## Canonical sources

- [Repository README](https://github.com/shikanime-labs/knix#readme)
- [Technical wiki](https://github.com/shikanime-labs/knix/wiki)
  ([Modules](https://github.com/shikanime-labs/knix/wiki/Modules),
  [Topologies](https://github.com/shikanime-labs/knix/wiki/Topologies))

In-repo `docs/` is canonical for technical detail; the wiki is a rendered human
index that links here.
