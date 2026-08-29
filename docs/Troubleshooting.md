<!-- owner: shikanime | zone: internal | purpose: known failure modes and the first-responder fix for each -->

# Troubleshooting

## Cluster will not reach etcd quorum

**Symptom:** servers stay `NotReady` / control plane never forms in HA.
**Cause:** `tokenFile` mismatch between servers, or `serverAddr` pointing at a
dead node. **Fix:** confirm every server uses the same sops `rke2-token` and a
reachable `serverAddr` (VIP/DNS); the first server initializes etcd, the rest
join as voters.

## Worker initialises another control plane

**Symptom:** an agent node spins up its own server instead of joining.
**Cause:** `services.knix.role` left at the default `server`. **Fix:** set
`services.knix.role = "agent"` on worker-only nodes.

## An addon never deploys

**Symptom:** Flux/Longhorn/Traefik missing after rebuild. **Cause:** the addon
`enable` is false, or `extraConfig` is malformed. **Fix:** set
`services.knix.addons.<name>.enable = true` and validate `extraConfig` against
the chart's values; `nix flake check` catches type errors.

## `nix fmt` fails on a docs page

**Cause:** treefmt's rumdl-check rejects Markdown lines over 80 columns.
**Fix:** wrap the offending lines to ≤80 and re-run `nix fmt` until clean.
