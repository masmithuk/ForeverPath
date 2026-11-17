#!/usr/bin/env bash
# Builds the installable addon zip: dist/Questwalker-<version>.zip
#
# The zip holds a single Questwalker/ folder with only what the game needs
# (the .toc, Bindings.xml and the Lua folders) plus the licence, readme and
# changelog. Tests, docs and tooling are left out.
#
# Usage: scripts/package.sh            -> uses the version in Questwalker.toc
#        scripts/package.sh 1.2.3      -> also checks the .toc says 1.2.3
#
# Adapted from Coin Forge's release setup.
set -euo pipefail

cd "$(dirname "$0")/.."
addon=Questwalker

toc_version=$(sed -n 's/^## Version: *//p' "$addon.toc" | tr -d '\r')
version="${1:-$toc_version}"
version="${version#v}"
if [ "$version" != "$toc_version" ]; then
  echo "Version mismatch: asked for $version but $addon.toc says $toc_version." >&2
  echo "Update '## Version:' in $addon.toc (and CHANGELOG.md) before releasing." >&2
  exit 1
fi

# Every file the .toc loads must exist, or the addon breaks in game.
# (The .toc uses Windows-style backslashes.)
missing=0
while read -r file; do
  if [ ! -f "$file" ]; then echo "Listed in $addon.toc but missing: $file" >&2; missing=1; fi
done < <(grep -E '^[^#].*\.(lua|xml)\s*$' "$addon.toc" | tr -d '\r' | tr '\\' '/')
[ "$missing" -eq 0 ] || exit 1

out="dist/$addon-$version.zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$addon" dist
cp -R "$addon.toc" Bindings.xml Core Data Guide Integrations Locales UI \
  LICENSE README.md CHANGELOG.md "$stage/$addon/"
rm -f "$out"
(cd "$stage" && zip -qr -X "$OLDPWD/$out" "$addon")
echo "$out"
