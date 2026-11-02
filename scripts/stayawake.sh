#!/usr/bin/env bash
# Keeps a Google TV / Android TV device such as a Chromecast with Google TV awake, so it
# never goes to sleep on its own and never sends the TV to standby over HDMI-CEC when
# nobody touches the remote. Each value it replaces is kept on the device in a
# dumbtv_stayawake_* global setting, and --undo puts it back.
# Usage: ./scripts/stayawake.sh [-y] [--dry-run]
# Undo:  ./scripts/stayawake.sh --undo
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# namespace key value. 2147483647 ms is about 24 days, the largest value Android takes.
SETTINGS="
system screen_off_timeout 2147483647
secure sleep_timeout -1
secure attentive_timeout -1
global stay_on_while_plugged_in 7
global hdmi_control_auto_device_off_enabled 0
"
SAVE=dumbtv_stayawake_

args=()
for a in "$@"; do
  case $a in
    --undo) UNDO=1 ;;
    *) args+=("$a") ;;
  esac
done
parse_flags ${args[@]+"${args[@]}"}
need_device
is_fireos && die "this is a Fire TV: dumbtv home keeps it awake (./scripts/launcher.sh -y)"

if [[ ${UNDO:-0} == 1 ]]; then
  step "undo"
  printf '%s\n' "$SETTINGS" | while read -r ns key _; do
    [[ -n $key ]] || continue
    prev=$(dev1 "settings get global $SAVE$key")
    case $prev in
      ''|null) continue ;;                          # never changed by this script
      unset) acmd "settings delete $ns $key" >/dev/null ;;
      *) acmd "settings put $ns $key $prev" >/dev/null ;;
    esac
    acmd "settings delete global $SAVE$key" >/dev/null
    printf '  %-46s %s\n' "$ns/$key" "back to $prev"
  done
  note "the device sleeps again as it did before"
  exit 0
fi

step "plan"
note "device   $(dev1 getprop ro.product.model), Android $(dev1 getprop ro.build.version.release)"
printf '%s\n' "$SETTINGS" | while read -r ns key val; do
  [[ -n $key ]] || continue
  printf '  %-46s %s -> %s\n' "$ns/$key" "$(dev1 "settings get $ns $key")" "$val"
done
confirm "Keep $SERIAL awake?" || die "cancelled"

step "settings"
printf '%s\n' "$SETTINGS" | while read -r ns key val; do
  [[ -n $key ]] || continue
  cur=$(dev1 "settings get $ns $key")
  # Keep the first value seen, so running this twice still undoes to the original.
  saved=$(dev1 "settings get global $SAVE$key")
  if [[ -z $saved || $saved == null ]] && [[ $cur != "$val" ]]; then
    [[ -z $cur || $cur == null ]] && cur=unset
    acmd "settings put global $SAVE$key $cur" >/dev/null
  fi
  acmd "settings put $ns $key $val" >/dev/null
  [[ $DRY_RUN == 1 ]] || printf '  %-46s %s\n' "$ns/$key" "$(dev1 "settings get $ns $key")"
done

step "done"
note "the device no longer sleeps or turns the TV off on its own; the screensaver still runs"
note "if the TV still turns off, it is the TV's own timer: look in the TV's menu for"
note "an eco, energy saving, auto power off or sleep timer setting and turn it off"
note "undo: ./scripts/stayawake.sh --undo"
