#!/usr/bin/env bash
# The Fire TV pass, as far as it carries over, for a Google TV device such as a Chromecast
# with Google TV: disables the ad and telemetry packages in data/androidtv/packages.txt,
# filters DNS with Private DNS, installs dumbtv home with the HOME swap from
# docs/OTHER-TVS.md, and optionally sets a wallpaper. Assistant and Netflix are kept.
# Usage: ./scripts/googletv.sh path/to/dumbtv-home.apk [wallpaper.jpg|.png] [-y]
# Undo:  ./scripts/googletv.sh --undo
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PKG=tv.dumbtv.home
MEDIA=/sdcard/Android/media/$PKG
# AdGuard's public resolver: blocks ad and tracker hosts for the whole device, no app needed.
DNS_HOST=${DNS_HOST:-dns.adguard-dns.com}
# setupwraith first: while it is enabled and launcherx is not, it answers HOME and can
# crash-loop system_server (docs/OTHER-TVS.md).
STOCK_HOME="com.google.android.tungsten.setupwraith com.google.android.apps.tv.launcherx com.google.android.tvlauncher"

args=()
for a in "$@"; do
  case $a in
    -y|--yes) ASSUME_YES=1 ;;
    --undo) UNDO=1 ;;
    *) args+=("$a") ;;
  esac
done
need_device
is_fireos && die "this is a Fire TV: use ./scripts/all.sh"

if [[ ${UNDO:-0} == 1 ]]; then
  for p in $STOCK_HOME $(list_of "$DATA/androidtv/packages.txt"); do
    dev "pm enable --user 0 $p" >/dev/null 2>&1
  done
  dev "settings put global private_dns_mode opportunistic" >/dev/null
  note "Google TV home, the disabled packages and the default DNS are back"
  note "dumbtv home stays installed: adb uninstall $PKG"
  exit 0
fi

APK=${args[0]:-}
WALL=${args[1]:-}
[[ -f $APK ]] || die "usage: $0 path/to/dumbtv-home.apk [wallpaper] (the dumbtv-home-apk CI artifact)"
[[ -z $WALL || -f $WALL ]] || die "no wallpaper at '$WALL'"

step "plan"
note "device         $(dev1 getprop ro.product.model), Android $(dev1 getprop ro.build.version.release)"
note "disable        ads and telemetry from data/androidtv/packages.txt (Assistant and Netflix kept)"
note "dns            Private DNS: $DNS_HOST"
note "home screen    dumbtv home from $APK; Google TV's home is disabled, not removed"
[[ -n $WALL ]] && note "wallpaper      $WALL"
confirm "Clean up $SERIAL?" || die "cancelled"

step "packages"
for p in $(list_of "$DATA/androidtv/packages.txt"); do
  if ! dev "pm path $p" | grep -q '^package:'; then
    printf '  %-48s absent\n' "$p"; continue
  fi
  printf '  %-48s %s\n' "$p" "$(dev1 "pm disable-user --user 0 $p")"
done

step "dns"
dev "settings put global private_dns_specifier $DNS_HOST" >/dev/null
dev "settings put global private_dns_mode hostname" >/dev/null
note "private_dns_mode=$(dev1 settings get global private_dns_mode) specifier=$(dev1 settings get global private_dns_specifier)"

step "dumbtv home"
note "if the TV shows a Play Protect warning, answer it on the remote; if it only offers 'Got it',"
note "turn off Play Store > profile > Play Protect > gear > Scan apps, run this again, then turn it back on"
out=$("$ADB" -s "$SERIAL" install -r "$APK" 2>&1 | grep -m1 -E 'Success|Failure|failed' || true)
note "${out:-no answer from adb install}"
dev "pm path $PKG" | grep -q '^package:' || die "dumbtv home is not installed, so Google TV's home stays on"
for p in $STOCK_HOME; do
  dev "pm path $p" | grep -q '^package:' || continue
  printf '  %-48s %s\n' "$p" "$(dev1 "pm disable-user --user 0 $p")"
done
dev "cmd package set-home-activity $PKG/.Home" >/dev/null 2>&1

if [[ -n $WALL ]]; then
  step "wallpaper"
  ext=${WALL##*.}
  dev "mkdir -p $MEDIA" >/dev/null
  "$ADB" -s "$SERIAL" push "$WALL" "$MEDIA/wallpaper.$(printf '%s' "$ext" | tr 'A-Z' 'a-z')" | tail -1
  dev "printf 'background=image\ndim=20\n' > $MEDIA/home.conf" >/dev/null
fi

dev "am start -a android.intent.action.MAIN -c android.intent.category.HOME" >/dev/null 2>&1
step "done"
note "press HOME on the remote: dumbtv home should open"
note "wait about 40 s before any reboot: a disable can take that long to be saved"
note "undo everything: ./scripts/googletv.sh --undo"
