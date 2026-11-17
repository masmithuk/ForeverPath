#!/usr/bin/env bash
# Prints the newest CHANGELOG.md entry (from the first "## " heading up to the
# next one, without the heading), used as the release notes on GitHub and
# CurseForge.
set -euo pipefail
cd "$(dirname "$0")/.."
awk '/^## /{n++; next} n==1' CHANGELOG.md | sed '/./,$!d'
