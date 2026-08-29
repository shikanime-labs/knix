<!-- owner: shikanime | zone: internal | purpose: docs landing + index for the knix RKE2 NixOS module repo -->

# Knix — Documentation

An opinionated NixOS module set for bootstrapping an RKE2 cluster. It gives a
solid default cluster layout while keeping the public surface small enough to
understand and customize. It ships no running service of its own — it renders
RKE2 charts and manifests onto a NixOS host.

## Internal ops

- [Architecture](./Architecture.md) — the module tree, the addon preset model,
  and the three supported cluster topologies.
- [Development](./Development.md) — local setup, the format/check loop, and how
  to add an addon.
- [Runbook](./Runbook.md) — how to consume, pick a topology, and protect the
  repo.
- [Troubleshooting](./Troubleshooting.md) — etcd quorum, worker roles, and addon
  deploy failures.
- [Reference](./Reference.md) — the `services.knix.*` option surface.

## User-facing docs

The user guide lives in the repo [README](../README.md) (quick start,
topologies, full option tables). It is the canonical source for consumers; this
`docs/` directory owns internal ops only and links out rather than duplicating
it.
