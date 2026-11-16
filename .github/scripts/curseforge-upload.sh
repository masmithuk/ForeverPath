#!/usr/bin/env bash
# Upload a release zip to CurseForge for WoW Forever.
# Usage: curseforge-upload.sh <zip> <notes.md>
# Env:   CF_API_KEY, CF_PROJECT_ID, optional CF_GAME_VERSION_ID, VERSION, ADDON
set -euo pipefail
zip="$1"
notes="$2"
api="https://wow.curseforge.com/api"

# Which game version to tag the file with: the configured id, or the newest
# version of the game version type whose name mentions "Forever".
game_version="${CF_GAME_VERSION_ID:-}"
if [ -z "$game_version" ]; then
    types=$(curl -sf -H "X-Api-Token: $CF_API_KEY" "$api/game/version-types")
    type_id=$(echo "$types" | jq -r '[.[] | select((.name + " " + .slug) | test("forever"; "i"))][0].id // empty')
    if [ -z "$type_id" ]; then
        echo "::error::No 'Forever' game version type on CurseForge. Version types it offers:"
        echo "$types" | jq -r '.[] | "  \(.id)  \(.name)"'
        echo "Set the CURSEFORGE_GAME_VERSION_ID variable to the right game version id."
        exit 1
    fi
    versions=$(curl -sf -H "X-Api-Token: $CF_API_KEY" "$api/game/versions")
    game_version=$(echo "$versions" | jq -r --argjson t "$type_id" \
        '[.[] | select(.gameVersionTypeID == $t)] | max_by(.id) | .id // empty')
    name=$(echo "$versions" | jq -r --argjson v "${game_version:-0}" '.[] | select(.id == $v) | .name')
    if [ -z "$game_version" ]; then
        echo "::error::No game versions under type $type_id; set CURSEFORGE_GAME_VERSION_ID."
        exit 1
    fi
    echo "Using WoW Forever game version $name (id $game_version)"
fi

release_type="release"
case "${VERSION:-}" in *-*) release_type="beta" ;; esac

# Sent from a file: curl -F would split an inline value at ";" (and the
# changelog has plenty), which CurseForge then rejects as invalid JSON.
jq -n \
    --arg changelog "$(cat "$notes")" \
    --arg name "${ADDON:-Questwalker} ${VERSION:-}" \
    --arg type "$release_type" \
    --argjson gv "$game_version" \
    '{changelog: $changelog, changelogType: "markdown", displayName: $name,
      gameVersions: [$gv], releaseType: $type}' > metadata.json

response=$(curl -s -w '\n%{http_code}' -H "X-Api-Token: $CF_API_KEY" \
    -F "metadata=<metadata.json" -F "file=@$zip" \
    "$api/projects/$CF_PROJECT_ID/upload-file")
code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')
if [ "$code" != "200" ]; then
    echo "::error::CurseForge upload failed (HTTP $code): $body"
    exit 1
fi
echo "Uploaded to CurseForge: file id $(echo "$body" | jq -r '.id')"
