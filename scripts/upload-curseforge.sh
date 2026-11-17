#!/usr/bin/env bash
# Uploads a packaged zip to CurseForge as a WoW Forever file.
#
# Uses the CurseForge Upload API:
#   GET  https://wow.curseforge.com/api/game/versions              (find the game version id)
#   POST https://wow.curseforge.com/api/projects/<id>/upload-file  (metadata + file)
#
# Environment:
#   CF_API_KEY      CurseForge API token (GitHub secret)            required
#   CF_PROJECT_ID   numeric CurseForge project id (GitHub variable) required
#   GAME_VERSION    CurseForge game version name, default 1.60.1 (WoW Forever)
#   DRY_RUN=1       print what would be uploaded instead of uploading;
#                   reads game versions from VERSIONS_JSON (a file) if set
#
# Usage: scripts/upload-curseforge.sh dist/Questwalker-1.2.3.zip 1.2.3
#
# Adapted from Coin Forge's release setup. One difference: the metadata is
# sent from a file. curl -F "metadata=<inline json>" splits the value at ";",
# and CurseForge then rejects changelogs containing semicolons as invalid JSON.
set -euo pipefail

cd "$(dirname "$0")/.."
zip="$1"
version="${2#v}"
game_version="${GAME_VERSION:-1.60.1}"
api="https://wow.curseforge.com/api"

[ -f "$zip" ] || { echo "No such file: $zip" >&2; exit 1; }
if [ -z "${DRY_RUN:-}" ]; then
  : "${CF_API_KEY:?Set the CF_API_KEY secret (a CurseForge API token).}"
  : "${CF_PROJECT_ID:?Set the CF_PROJECT_ID variable (your CurseForge project id).}"
fi

# alpha / beta in the version mark a test release; anything else is a full release
case "$version" in
  *alpha*) release_type=alpha ;;
  *beta*) release_type=beta ;;
  *) release_type=release ;;
esac

if [ -n "${DRY_RUN:-}" ] && [ -n "${VERSIONS_JSON:-}" ]; then
  versions=$(cat "$VERSIONS_JSON")
else
  versions=$(curl -fsS -H "x-api-token: ${CF_API_KEY:-}" "$api/game/versions")
fi
ids=$(jq -c --arg name "$game_version" '[.[] | select(.name == $name) | .id]' <<<"$versions")
if [ "$ids" = "[]" ]; then
  echo "CurseForge has no game version named $game_version." >&2
  exit 1
fi

metadata_file=$(mktemp)
trap 'rm -f "$metadata_file"' EXIT
jq -n \
  --arg name "Questwalker $version" \
  --arg type "$release_type" \
  --arg changelog "$(scripts/changelog.sh)" \
  --argjson versions "$ids" \
  '{displayName: $name, releaseType: $type, changelog: $changelog, changelogType: "markdown",
    gameVersions: $versions}' > "$metadata_file"

if [ -n "${DRY_RUN:-}" ]; then
  echo "Would upload $zip to project ${CF_PROJECT_ID:-<unset>} with:"
  cat "$metadata_file"
  exit 0
fi

status=$(curl -sS -o upload-response.json -w "%{http_code}" \
  -H "x-api-token: $CF_API_KEY" \
  -F "metadata=<$metadata_file" \
  -F "file=@$zip" \
  "$api/projects/$CF_PROJECT_ID/upload-file")
if [ "$status" != "200" ]; then
  echo "CurseForge upload failed (HTTP $status):" >&2
  cat upload-response.json >&2
  exit 1
fi
echo "Uploaded to CurseForge: file id $(jq -r .id upload-response.json)"
