# IPv6 Privacy Extensions and Cluster Networking

## The Short Version

Privacy extensions generate rotating, temporary IPv6 addresses for your host.
This is good for personal privacy on a laptop and bad for Kubernetes cluster
networking. Knix disables them.

## What Are Privacy Extensions?

When a host gets an IPv6 address via SLAAC (Stateless Address Auto
Configuration, the IPv6 equivalent of DHCP), the address is normally derived
from the network prefix (advertised by the router) and the host's MAC address.
This produces a **stable** address that never changes as long as the hardware
doesn't change. It also means every IPv6 packet you send can be traced back to
your machine by its MAC-derived suffix.

Privacy extensions (RFC 4941) solve the tracking problem by generating **random,
temporary** addresses that rotate every few hours. Outbound connections use the
temporary address, so the stable address is never exposed. The stable address
still exists for inbound connections.

## The `use_tempaddr` Sysctl

The kernel setting that controls this is `net.ipv6.conf.<iface>.use_tempaddr`.
It has three values:

| Value | Meaning                                                     |
| ----- | ----------------------------------------------------------- |
| `0`   | Disabled. Only the stable address is used.                  |
| `1`   | Enabled. Stable address preferred, temp available.          |
| `2`   | Enabled and preferred. Temporary address used for outbound. |

NixOS sets `use_tempaddr = 2` by default on most interfaces. For a laptop on
public Wi-Fi, that's the right call. For a Kubernetes node, it's a bug.

## Why This Breaks Canal `host-gw`

Canal (Calico + Flannel) in `host-gw` mode routes pod traffic between nodes
using the **node's own IP address as the next-hop gateway**. For IPv4, this is
simple: nodes have stable IPv4 addresses (static or DHCP-leased), and routes
point at them permanently.

For IPv6, canal reads the node's global IPv6 addresses and installs them as
route next-hops. If privacy extensions are on (`use_tempaddr = 2`), canal may
pick up a **temporary** address. That address rotates every few hours. When it
expires:

1. The old next-hop address no longer exists on the remote node.
2. Neighbor discovery (IPv6 ARP equivalent) fails to resolve it.
3. The kernel marks the neighbor as `FAILED` in the neighbor table.
4. Every route using that next-hop becomes a black hole.

Until canal detects the change and re-programs routes with a new address, all
IPv6 cross-node pod traffic dies. This is silent, intermittent, and extremely
hard to debug.

## What Happened on the Nishir Cluster

The nishir cluster runs dual-stack IPv4/IPv6 with canal `host-gw`. The nodes had
`use_tempaddr = 2`:

```sh
$ cat /proc/sys/net/ipv6/conf/br0/use_tempaddr
2
```

And `br0` had multiple rotating temporary addresses:

```text
inet6 2a02:...:b341:e3c5:646e:38f3/64 scope global temporary dynamic
inet6 2a02:...:f4cd:5553:948e:396a/64 scope global temporary deprecated dynamic
inet6 2a02:...:6014:8855:5e5e:fc4f/64 scope global temporary deprecated dynamic
```

The neighbor table on each node showed next-hops for remote pod CIDRs in
`FAILED` state:

```text
2a02:...:325a:aa5b dev br0 FAILED    # nemishi pod CIDR next-hop
2a02:...:3d1e:dc02:1642:b0c8 dev br0 FAILED
2a02:...:947e:2262:ded1:58f dev br0 FAILED
```

The IPv6 kube-dns Service VIP (`fd01::a`) DNATs to CoreDNS pod IPs on remote
nodes. Since cross-node IPv6 routing was dead, the VIP was unreachable. Go-based
DNS resolvers (Caddy in `synapse-proxy`) that round-robin between IPv4 and IPv6
DNS servers would sometimes hit the dead IPv6 VIP, time out, and return `502`.

## The Fix

Knix sets `use_tempaddr = 0` on the cluster interface and on `default` (so any
new interface inherits it):

```nix
"net.ipv6.conf.${cfg.interface}.use_tempaddr" = 0;
"net.ipv6.conf.default.use_tempaddr" = 0;
```

This forces nodes to use stable SLAAC addresses (derived from the MAC or a fixed
suffix). Canal's next-hops stop rotating, neighbor discovery stays `REACHABLE`,
and IPv6 cross-node pod routing works permanently.

## Verifying the Fix

After deploying to a node:

```sh
# Should print 0
cat /proc/sys/net/ipv6/conf/br0/use_tempaddr

# Should show no "temporary" addresses, only stable ones
ip -6 addr show br0 | grep temporary
# (no output = correct)

# Next-hops should be REACHABLE or STALE, not FAILED
ip -6 neigh | grep FAILED
# (no output = correct)
```
