# chdman — unofficial static AppImage

[![Build and release](https://github.com/hcet-sudo/chdman-appimage/actions/workflows/release.yml/badge.svg)](https://github.com/hcet-sudo/chdman-appimage/actions/workflows/release.yml)

Unofficial, **fully static** AppImage of MAME's `chdman` (Compressed Hunks of
Data manager) for x86_64 Linux. Static means no glibc or library requirements
whatsoever — it runs on any distribution, however old or new, including
minimal containers and distros without FUSE.

Built automatically from the latest [MAME](https://github.com/mamedev/mame)
release every week. Companion repo:
[unecm-appimage](https://github.com/hcet-sudo/unecm-appimage) (decodes `.ecm`
files — chdman cannot read them).

## Install

### With am / appman

```
am -e https://github.com/hcet-sudo/chdman-appimage chdman chdman
```

### Direct download (stable URL)

```
curl -LO https://github.com/hcet-sudo/chdman-appimage/releases/latest/download/chdman-x86_64.AppImage
chmod +x chdman-x86_64.AppImage
```

Without FUSE, run `./chdman-x86_64.AppImage --appimage-extract-and-run ...`.

## Usage

```
./chdman-x86_64.AppImage createcd  -i game.cue -o game.chd   # CD image -> CHD
./chdman-x86_64.AppImage createdvd -i game.iso -o game.chd   # DVD image -> CHD
./chdman-x86_64.AppImage extractcd -i game.chd -o out.cue    # CHD -> cue/bin
./chdman-x86_64.AppImage verify    -i game.chd
./chdman-x86_64.AppImage info      -i game.chd
```

Have a `.bin.ecm`? That is ECM format, not CHD — decode it first with
[unecm](https://github.com/hcet-sudo/unecm-appimage), then use the cue sheet
above (a minimal one for MODE1/2352 images):

```
FILE "game.bin" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00
```

## How releases work (pkgforge-style)

The GitHub Actions workflow (`.github/workflows/release.yml`) runs every
Monday and on demand, then:

1. Resolves the latest MAME release tag via the GitHub API.
2. Builds `chdman` **statically** from that tag's source.
3. **Self-tests it** — generates a valid MODE1/2352 CD image, converts it
   with `createcd`, extracts it back with `extractcd`, and requires
   bit-identical results, plus `verify` and `info` on the CHD.
4. **ISA-gates it** — the release only publishes if the same bit-perfect
   self-test also passes under `qemu` emulating a **baseline x86-64-v1**
   CPU. Any v2+ instruction (from our code or from prebuilt static glibc)
   dies with SIGILL there and blocks the release — so the AppImage runs on
   every x86_64 CPU, however old.
5. Publishes a release tagged `<ver>@<date>_<epoch>` (e.g.
   `0.289@2026-11-17_1763...`) with the stable asset name
   `chdman-x86_64.AppImage`, so `releases/latest/download/...` always points
   at the newest build.

Manual runs: **Actions → Build and release → Run workflow** (optionally pin a
MAME tag, e.g. `mame0289`). Pushes that touch `build/` or the workflow also
rebuild.

## Building locally

```
sudo apt-get install -y gcc g++ make python3 libsdl2-dev libfontconfig1-dev
bash build/build-chdman.sh mame0289                  # downloads + compiles MAME tools
bash build/self-test-chdman.sh dist/chdman-x86_64.AppImage
```

The recipe builds only the tools (`EMULATOR=0`, no Qt debugger, no MIDI, no
bgfx) and links them statically (`LDOPTS="-static"`, plus no-op SDL clipboard
stubs — see `build/build-chdman.sh`), so the result has zero runtime
dependencies.

## Publishing your fork

1. Replace `hcet-sudo` with your GitHub username in this README:
   `grep -rl hcet-sudo . | xargs sed -i 's/hcet-sudo/yourname/g'`.
2. Push the repo to GitHub (terminal or the web UI's "Upload files" flow —
   the workflows invoke scripts via `bash`, so missing execute bits on
   web-uploaded files don't matter).
3. Repo Settings → Actions → General → Workflow permissions → **Read and
   write** (the release job needs write access to publish releases).
4. Test with Actions → "Build and release" → Run workflow; the weekly cron
   then tracks new MAME releases automatically.

To make plain `am -i chdman` work for everyone, submit an installation
script to the [AM database](https://github.com/ivan-hc/AM): run
`am -t chdman`, choose the GitHub option, then open a PR adding the
generated script to `programs/x86_64/` and its name to the `x86_64-apps`
list. (As of Nov 2026 there is no chdman entry in the AM database — you
would be the first.)

## License

- MAME and `chdman` are distributed under the **GNU GPL v2 or later**
  (`LICENSE-MAME` is MAME's `COPYING` verbatim). MAME is a registered
  trademark of Gregory Ember.
- Build scripts and icons in this repo: GPL-2.0-or-later, same license.
- This is an unofficial build; file MAME bugs upstream at
  [mamedev/mame](https://github.com/mamedev/mame), and build issues here.
