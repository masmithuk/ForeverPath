# Releasing

A release is one GitHub release. Publishing it starts `.github/workflows/release.yml`, which:

1. lints and runs the tests,
2. builds `dist/Questwalker-<version>.zip` with `scripts/package.sh` (only the files the game needs),
3. attaches the zip to the release (and fills in empty release notes from `CHANGELOG.md`),
4. uploads the zip to CurseForge as a **WoW Forever (1.60.1)** file with `scripts/upload-curseforge.sh`.

(This is the same setup as Coin Forge's.)

## One-time setup

1. **Create the CurseForge project** at <https://authors.curseforge.com> (World of Warcraft > Addons). New
   projects are reviewed by CurseForge moderators before they go public, and so is the first file.
2. **Note the project id**, shown under "About This Project" on the project's overview page (or in the
   dashboard URL, `authors.curseforge.com/#/projects/<ID>/...`).
3. **Create an API token** at <https://www.curseforge.com/account/api-tokens> (not on authors.curseforge.com).
4. In the GitHub repo, open **Settings > Secrets and variables > Actions** and add:
   - secret **`CF_API_KEY`**: the API token
   - variable **`CF_PROJECT_ID`**: the project id (a secret of the same name works too, and so does the older
     `CURSEFORGE_PROJECT_ID` variable)

## Each release

1. Update `## Version:` in `Questwalker.toc` and add an entry at the top of `CHANGELOG.md`
   (`## [x.y.z] - date`). Run `luacheck .` and `lua5.1 tests/run.lua`, commit and push to `main`.
2. On GitHub, go to **Releases > Draft a new release**, create a tag with the same version (`0.8.5` or
   `v0.8.5`, either works) on `main`, leave the notes empty and click **Publish release**.

   Or from a terminal signed in with `gh auth login`:
   `gh release create v0.8.5 --target main --title "Questwalker 0.8.5" --notes ""`

The workflow refuses to release if the tag and the `.toc` version differ. Tags containing `alpha` or `beta`
(for example `0.9.0-beta1`) are uploaded to CurseForge as alpha/beta files.

If a run fails (a missing secret, say), fix the cause and click **Re-run jobs** on the run. To release an
existing tag without making a new release, use **Actions > Release > Run workflow**.

## Checking locally

```sh
scripts/package.sh                 # builds dist/Questwalker-<version>.zip
DRY_RUN=1 CF_API_KEY=... CF_PROJECT_ID=... scripts/upload-curseforge.sh dist/Questwalker-0.8.4.zip 0.8.4
```

`DRY_RUN=1` prints the CurseForge metadata instead of uploading.

## Who does what

Claude sessions in the cloud can push commits to `main` (step 1) but can't create tags or releases, so step 2 is
always done by a person. They can read the workflow runs to check how a release went.
