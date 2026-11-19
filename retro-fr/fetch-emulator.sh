#!/usr/bin/env bash
# Télécharge EmulatorJS et les cœurs d'émulation depuis npm dans web/emulator/.
# Rien de tout ça n'est versionné : le script est lancé avant chaque compilation.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION=4.2.3
CORES=(fceumm snes9x gambatte mgba genesis_plus_gx picodrive pcsx_rearmed
       mupen64plus_next melonds stella2014 prosystem handy mednafen_pce
       mednafen_ngp mednafen_wswan beetle_vb)

DEST=web/emulator
WORK=$(mktemp -d "${TMPDIR:-/tmp}/retro-fr.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

pack() { (cd "$WORK" && npm pack --silent "$1@$VERSION" >/dev/null) ; }

rm -rf "$DEST"
mkdir -p "$DEST/cores/reports"

pack @emulatorjs/emulatorjs
mkdir "$WORK/ejs"
tar xzf "$WORK"/emulatorjs-emulatorjs-"$VERSION".tgz -C "$WORK/ejs"
cp -R "$WORK/ejs/package/data/." "$DEST/"
cp "$WORK/ejs/package/LICENSE" "$DEST/LICENSE-EmulatorJS.txt"

for c in "${CORES[@]}"; do
  pack "@emulatorjs/core-$c"
  mkdir "$WORK/$c"
  tar xzf "$WORK/emulatorjs-core-$c-$VERSION.tgz" -C "$WORK/$c"
  # Les variantes « thread » exigent SharedArrayBuffer, inutile ici.
  cp "$WORK/$c/package/$c-wasm.data" "$WORK/$c/package/$c-legacy-wasm.data" "$DEST/cores/"
  cp "$WORK/$c/package/reports/$c.json" "$DEST/cores/reports/"
  echo "cœur $c"
done

du -sh "$DEST"
