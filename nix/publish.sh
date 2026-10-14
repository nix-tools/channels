# Publish one week of nixos-unstable: resolve the release the channel currently points at,
# recompress upstream's expression tarball to zstd, prove it is usable before anyone can
# depend on it, and cut a GitHub release named after the ISO week.
#
# The week lives in the tag and the asset name never changes, so the redirector in front of
# channels.nix.tools stays one static rule instead of a weekly deployment.
#
# Writing channels/index.json is the last step and committing it is left to the caller: git
# identity and push rights are CI policy, and a dirty working tree is the right outcome for
# a local run.

repo=nix-tools/channels
upstream=nixos-unstable
asset=nixpkgs.tar.zst

week=
force=0
dry_run=0

die() {
  echo "publish: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: publish [--week YYYY-Www] [--force] [--dry-run]

  --week     Publish as this ISO week instead of the current one.
  --force    Replace an existing release for that week, tag included.
  --dry-run  Build and check the tarball, publish nothing.
USAGE
}

while (($#)); do
  case $1 in
    --week)
      week=${2:-}
      [[ -n $week ]] || die "--week needs a value"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

week=${week:-$(date -u +%G-W%V)}
[[ $week =~ ^[0-9]{4}-W[0-9]{2}$ ]] || die "week must look like 2026-W42, got: $week"

index=
if ((!dry_run)); then
  root=$(git rev-parse --show-toplevel 2>/dev/null) ||
    die "run from a checkout of $repo: the published week is recorded in channels/index.json"
  index=$root/channels/index.json
  [[ -f $index ]] || die "no $index"
fi

# channels.nixos.org/$upstream redirects to the release directory Hydra last promoted, which
# is the one piece of state upstream exposes: everything else is derived from its name.
release_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://channels.nixos.org/$upstream")
release_url=${release_url%/}
release=${release_url##*/}
rev=$(curl -fsSL "$release_url/git-revision")
echo "publish: $week <- $release ($rev)"

if gh release view "$week" --repo "$repo" >/dev/null 2>&1; then
  if ((dry_run)); then
    echo "publish: release $week already exists; a real run would need --force" >&2
  elif ((force)); then
    gh release delete "$week" --repo "$repo" --cleanup-tag --yes
  else
    die "release $week already exists; pass --force to replace it"
  fi
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 3 -o "$work/nixexprs.tar.xz" "$release_url/nixexprs.tar.xz"

# Stream recompression: the tar is byte-identical to upstream's, so the unpacked tree, and
# with it the narHash every consumer locks, is unchanged by the switch to zstd.
xz -dc "$work/nixexprs.tar.xz" | zstd -19 -T0 -q -o "$work/$asset"

url="tarball+file://$work/$asset"
nar_hash=$(nix flake prefetch --json "$url" | jq -r .hash)

# Three things worth failing on before publishing: Nix unpacks it, it evaluates, and the
# binary cache has the result. The last one is the entire reason this channel exists.
nix eval --raw "$url#lib.version" >/dev/null
nix build --no-link "$url#hello"

size=$(stat -c %s "$work/$asset")
printf 'publish: %s  %s  %s bytes\n' "$asset" "$nar_hash" "$size"

if ((dry_run)); then
  echo "publish: dry run, stopping before the release"
  exit 0
fi

download=https://github.com/$repo/releases/download/$week/$asset

cat >"$work/notes.md" <<NOTES
Weekly snapshot of \`$upstream\`, recompressed to zstd. Same tree as upstream, same narHash.

| | |
|---|---|
| upstream release | [\`$release\`]($release_url) |
| nixpkgs revision | [\`$rev\`](https://github.com/NixOS/nixpkgs/commit/$rev) |
| narHash | \`$nar_hash\` |

\`\`\`nix
inputs.nixpkgs.url = "$download";
\`\`\`
NOTES

gh release create "$week" "$work/$asset" \
  --repo "$repo" \
  --title "nixpkgs $week" \
  --notes-file "$work/notes.md"

entry=$(
  jq -n \
    --arg week "$week" \
    --arg rev "$rev" \
    --arg release "$release" \
    --arg source "$release_url/nixexprs.tar.xz" \
    --arg url "$download" \
    --arg narHash "$nar_hash" \
    --argjson size "$size" \
    --arg published "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '$ARGS.named'
)

tmp=$(mktemp)
jq --argjson entry "$entry" \
  '.weeks |= (map(select(.week != $entry.week)) + [$entry])' \
  "$index" >"$tmp"
mv "$tmp" "$index"

echo "publish: $download"
echo "publish: recorded in channels/index.json, commit it"
