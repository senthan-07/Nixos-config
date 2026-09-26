#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <key> [system]"
  echo "  key     top-level key in packages/source.json (e.g. zen-browser)"
  echo "  system  nix system triple (default: x86_64-linux)"
  echo
  echo "repo and asset are read from packages/source.json[\"<key>\"]."
  exit 1
}

[ $# -ge 1 ] || usage

KEY="$1"
SYSTEM="${2:-x86_64-linux}"
SOURCE_JSON="$(dirname "$0")/../packages/source.json"

OS="$(uname -s)"
if [ "$OS" != "Linux" ]; then
  echo "error: this script is intended to run on Linux (nix store prefetch-file required)" >&2
  exit 1
fi

read -r REPO ASSET <<< "$(
  python3 - "$SOURCE_JSON" "$KEY" <<'EOF'
import json, sys
path, key = sys.argv[1:3]
with open(path) as f:
    data = json.load(f)[key]
print(data.get("repo", ""), data.get("asset", ""))
EOF
)"

if [ -z "$REPO" ] || [ -z "$ASSET" ]; then
  echo "error: packages/source.json[\"$KEY\"] must define 'repo' and 'asset'" >&2
  exit 1
fi

current_version=$(
  python3 - "$SOURCE_JSON" "$KEY" <<'EOF'
import json, sys
path, key = sys.argv[1:3]
with open(path) as f:
    print(json.load(f)[key]["version"])
EOF
)

latest_version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')

echo "current: $current_version"
echo "latest:  $latest_version"

if [ "$current_version" = "$latest_version" ]; then
  echo "already up to date"
  exit 0
fi

url="https://github.com/$REPO/releases/download/$latest_version/$ASSET"

echo "prefetching $url ..."
hash=$(
  nix store prefetch-file --json "$url" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["hash"])'
)

python3 - "$SOURCE_JSON" "$KEY" "$SYSTEM" "$latest_version" "$url" "$hash" <<'EOF'
import json, sys
path, key, system, version, url, hash = sys.argv[1:7]
with open(path) as f:
    data = json.load(f)
data[key]["version"] = version
data[key]["sources"][system]["url"] = url
data[key]["sources"][system]["hash"] = hash
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF

echo "updated packages/source.json: $KEY -> $latest_version"