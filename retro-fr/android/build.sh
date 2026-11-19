#!/usr/bin/env bash
# Construit retro-fr/android/build/retro-fr.apk avec les seuls outils du SDK Android (sans Gradle).
# Il faut un JDK 17 et un SDK Android avec platforms;android-34 et des build-tools.
# L'émulateur (web/emulator) est téléchargé par ../fetch-emulator.sh s'il manque.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck disable=SC1091
source version.env

MIN_SDK=24
TARGET_SDK=34
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
JAR=$SDK/platforms/android-$TARGET_SDK/android.jar
BT=$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1 || true)
[[ -f $JAR ]] || { echo "erreur : $JAR manquant — sdkmanager 'platforms;android-$TARGET_SDK'" >&2; exit 1; }
[[ -x $BT/aapt2 ]] || { echo "erreur : pas de build-tools dans $SDK — sdkmanager 'build-tools;34.0.0'" >&2; exit 1; }

[[ -f ../web/emulator/loader.js ]] || ../fetch-emulator.sh

KEYSTORE=${RETROFR_KEYSTORE:-$PWD/retro-fr.keystore}
KEYPASS=${RETROFR_KEYPASS:-retrofr}
if [[ ! -f $KEYSTORE ]]; then
  keytool -genkeypair -keystore "$KEYSTORE" -alias retrofr -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$KEYPASS" -keypass "$KEYPASS" -dname "CN=Retro FR" >/dev/null
  echo "clé de signature créée : $KEYSTORE (gardez-la : les mises à jour doivent avoir la même)"
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/retro-fr-apk.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/gen" "$WORK/classes" "$WORK/assets" build
cp -R ../web "$WORK/assets/web"

"$BT/aapt2" compile --dir res -o "$WORK/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml "$WORK/res.zip" -A "$WORK/assets" \
  --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" \
  --java "$WORK/gen" -o "$WORK/app.apk"

find src "$WORK/gen" -name '*.java' > "$WORK/sources.txt"
javac --release 8 -Xlint:-options -encoding UTF-8 -classpath "$JAR" -d "$WORK/classes" @"$WORK/sources.txt"
find "$WORK/classes" -name '*.class' > "$WORK/classes.txt"
"$BT/d8" --release --min-api "$MIN_SDK" --lib "$JAR" --output "$WORK" @"$WORK/classes.txt"
(cd "$WORK" && zip -q -X app.apk classes.dex)

"$BT/zipalign" -f -p 4 "$WORK/app.apk" "$WORK/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass "pass:$KEYPASS" --key-pass "pass:$KEYPASS" \
  --out build/retro-fr.apk "$WORK/aligned.apk"
"$BT/apksigner" verify build/retro-fr.apk
echo "construit : build/retro-fr.apk ($(du -h build/retro-fr.apk | cut -f1))"
