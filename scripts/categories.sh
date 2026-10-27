#!/usr/bin/env bash
# Files the TV's apps into dumbtv home categories by package name, in one go.
# Usage: ./scripts/categories.sh "TV=disney|crunchyroll" "Music=spotify" [--rest Other] [-y]
# Each rule is Category=regex, matched case-insensitively against package names; the first
# rule that matches wins. --rest files every other app shown on the home screen there.
# Works on Fire OS 8 and Google TV alike: the result goes into the launcher's media
# folder, which it applies the next time the home screen comes back.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MEDIA=/sdcard/Android/media/tv.dumbtv.home
rules=() rest=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes) ASSUME_YES=1 ;;
    --rest) rest=${2:-}; shift ;;
    *=*) rules+=("$1") ;;
    *) die "not a Category=regex rule: $1" ;;
  esac
  shift
done
[[ ${#rules[@]} -gt 0 || -n $rest ]] || die "usage: $0 \"Category=regex\"... [--rest Category]"
need_device
dev "pm path tv.dumbtv.home" | grep -q '^package:' || die "dumbtv home is not installed on $SERIAL"

# The apps the home screen shows: every TV-launchable package, plus phone apps the user added.
apps=$(dev "cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER" \
  | grep -o 'packageName=[^ ]*' | cut -d= -f2 | tr -d '\r' | grep -v '^tv\.dumbtv\.home$' | sort -u)
[[ -n $apps ]] || die "could not list the TV's apps"

names=()
for r in ${rules[@]+"${rules[@]}"}; do names+=("${r%%=*}"); done
[[ -n $rest ]] && names+=("$rest")

step "plan"
lines=()
for p in $apps; do
  cat=""
  for r in ${rules[@]+"${rules[@]}"}; do
    if grep -qiE "${r#*=}" <<<"$p"; then cat=${r%%=*}; break; fi
  done
  [[ -z $cat ]] && cat=$rest
  printf '  %-12s %s\n' "${cat:-(Apps)}" "$p"
  [[ -n $cat ]] && lines+=("category.$p=$cat")
done
for r in ${rules[@]+"${rules[@]}"}; do
  grep -qiE "${r#*=}" <<<"$apps" || note "nothing matched ${r%%=*}=${r#*=}"
done
confirm "File these apps on $SERIAL?" || die "cancelled"

# Keeps whatever else the media file already sets (background, dim...).
old=$(dev "cat $MEDIA/home.conf 2>/dev/null" | tr -d '\r' | grep -vE '^(categories|category\.[^=]*)=' || true)
list=$(IFS=,; printf '%s' "${names[*]}")
{
  [[ -n $old ]] && printf '%s\n' "$old"
  printf 'categories=%s\n' "$list"
  [[ ${#lines[@]} -gt 0 ]] && printf '%s\n' "${lines[@]}"
} > "${TMPDIR:-/tmp}/dumbtv-home.conf"
dev "mkdir -p $MEDIA" >/dev/null
"$ADB" -s "$SERIAL" push "${TMPDIR:-/tmp}/dumbtv-home.conf" "$MEDIA/home.conf" | tail -1
rm -f "${TMPDIR:-/tmp}/dumbtv-home.conf"
dev "am start -a android.intent.action.MAIN -c android.intent.category.HOME" >/dev/null 2>&1
note "press HOME if the rows do not show; an app filed wrongly: hold OK on it > Category"
