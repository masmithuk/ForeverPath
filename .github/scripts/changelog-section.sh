#!/usr/bin/env bash
# Print the body of one version's section from a Keep-a-Changelog file:
# everything between "## [<version>]" and the next "## [" heading.
# Usage: changelog-section.sh <version> <CHANGELOG.md>
set -euo pipefail
version="$1"
file="$2"
awk -v v="$version" '
    /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
    found { print }
' "$file" | sed '/./,$!d'
