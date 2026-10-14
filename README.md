# channels

Unofficial, weekly Nix channels.

A snapshot of `nixos-unstable` is published every Monday as a GitHub release tagged after
the ISO week. Pinning one means a `flake.lock` that stays put for a week at a time, on a
revision [cache.nixos.org] has already built, instead of tracking a branch that moves
hourly and compiles locally whenever it moves faster than Hydra.

```nix
inputs.nixpkgs.url = "https://github.com/nix-tools/channels/releases/download/2026-W42/nixpkgs.tar.zst";
```

The tarball is upstream's `nixexprs.tar.xz` recompressed to zstd. Nix sniffs compression
from magic bytes and hashes the unpacked tree, so the narHash is the one upstream's own
tarball locks to, and switching compression again later would not move it either.

## Publishing

```
nix run .#publish -- --dry-run     # build and check this week's tarball, publish nothing
nix run .#publish                  # cut the release, record it in channels/index.json
```

A week is published only if Nix unpacks the tarball, nixpkgs evaluates from it, and a
package builds out of the binary cache. On failure the previous week stands.

`channels/index.json` is the audit log: one appended entry per week, with the upstream
release it came from, the revision, the narHash and the size. The releases are a cache of
it rather than the other way around, so a bad publish is a revert and a re-upload.

CI does the same thing on a cron, and `workflow_dispatch` runs it on demand:

```
gh workflow run weekly.yml
gh workflow run weekly.yml -f week=2026-W42 -f force=true
```

## Not here yet

- `channels.nix.tools/nixpkgs-2026-W42.tar.zst`, a static 302 to the release asset.
- A `latest` alias, for bootstrapping only: Nix locks the URL you wrote, so a lock file
  holding `latest` silently re-resolves on every refresh.
- A retention window, and a check a consumer flake can run to notice its pin aging out.
- Building the repos that depend on this channel before publishing it, rather than one
  package out of the cache.

[cache.nixos.org]: https://cache.nixos.org
