<!-- owner: shikanime | zone: internal | purpose: the services.knix.* option surface for consumers -->

# Reference

All options live under `services.knix.*`. `services.knix.enable = true` is the
main switch.

## Core

| Option                               | Default              | Purpose                 |
| ------------------------------------ | -------------------- | ----------------------- |
| `services.knix.enable`               | `false`              | Turn the module on.     |
| `services.knix.role`                 | `"server"`           | `server` or `agent`.    |
| `services.knix.nodeIP`               | `null`               | Node IP for RKE2.       |
| `services.knix.serverAddr`           | `""`                 | RKE2 server address.    |
| `services.knix.tokenFile`            | `null`               | RKE2 join token file.   |
| `services.knix.interface`            | `"enp1s0"`           | WAN iface for firewall. |
| `services.knix.clusterCidr`          | `"10.244.0.0/16"`    | IPv4 pod CIDR.          |
| `services.knix.clusterCidrIPv6`      | `"fd00::/108"`       | IPv6 pod CIDR.          |
| `services.knix.serviceCidr`          | `"10.96.0.0/12,..."` | Service CIDR.           |
| `services.knix.labels`               | `{}`                 | Node labels for RKE2.   |
| `services.knix.nodeCidrMaskSize`     | `24`                 | IPv4 node mask size.    |
| `services.knix.nodeCidrMaskSizeIPv6` | `64`                 | IPv6 node mask size.    |

## Addons (each `enable` + `extraConfig`)

| Addon        | Default `enable` | Role                       |
| ------------ | ---------------- | -------------------------- |
| `flux`       | `true`           | GitOps reconciliation.     |
| `longhorn`   | `true`           | Persistent storage.        |
| `traefik`    | `true`           | Ingress (Gateway API on).  |
| `canal`      | `true`           | CNI (`wireguard` backend). |
| `coredns`    | `true`           | Node DNS caching.          |
| `multus`     | `true`           | Multi-CNI meta-plugin.     |
| `prometheus` | `true`           | Monitoring.                |

## Exposed flake module

| Attribute              | Target | Source                |
| ---------------------- | ------ | --------------------- |
| `nixosModules.default` | NixOS  | `modules/default.nix` |

## Notes

- `services.knix.addons.flux.instance.extraConfig.instance.sync` passes Flux
  sync config through.
- Longhorn sets `node.longhorn.io/create-default-disk=config` automatically.
