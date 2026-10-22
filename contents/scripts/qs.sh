#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
#
# System helper for the Quick Settings plasmoid.
#
#   qs.sh poll                      audio and brightness as key=value lines
#   qs.sh netpoll                   Wi-Fi state as key=value lines
#   qs.sh miscpoll                  Night Color + Airplane mode as key=value lines
#   qs.sh cschemepoll               color scheme current + installed list as kv
#   qs.sh volume <0..1>             set output volume (and unmute)
#   qs.sh micvolume <0..1>          set input volume (and unmute)
#   qs.sh mute sink|source          toggle mute
#   qs.sh brightness <0..1>         set screen brightness
#   qs.sh wifi on|off               Wi-Fi radio
#   qs.sh wifiscan                  ask NetworkManager for a fresh scan
#   qs.sh wifilist                  visible networks, one "net=" line each
#   qs.sh wificonnect <ssid> saved|new
#   qs.sh wificonnectpw <ssid> <password>
#   qs.sh wifidisconnect
#   qs.sh nightcolor on|off         toggle KWin Night Color (writes kwinrc + reconfigure)
#   qs.sh colorscheme current       print current scheme name
#   qs.sh colorscheme list          print installed scheme names, one per line
#   qs.sh colorscheme set <name>    switch color scheme via plasma-apply-colorscheme
#   qs.sh airplane on|off           rfkill block/unblock all radios
#   qs.sh traypoll                  StatusNotifier items + Background Apps as kv/lines
#   qs.sh trayactivate <svc> <path> call Activate(0,0) on a StatusNotifierItem
#   qs.sh traymenu <svc> <path>     call ContextMenu(0,0) on a StatusNotifierItem
#   qs.sh traymenulayout <svc> <path>
#                                   StatusNotifierItem's DBusMenu tree, as
#                                   menu_status=/menu_path=/menujson= lines
#   qs.sh traymenuclick <svc> <menu_path> <id>
#                                   activate one DBusMenu entry (Event clicked)
#   qs.sh traymenuabout <svc> <menu_path> <id>
#                                   AboutToShow(id) for dynamically built menus
#   qs.sh trayopenapp <app_id>      bring a background app to the front
#   qs.sh traystopapp <instance>    stop a background app instance
#   qs.sh lock | power | screenshot
#   qs.sh settings [network|bluetooth|power|notifications|nightcolor|colors|virtualkeyboard|removabledevices]
#
# Actions that can fail in a way the user should see print
#   result=ok     or     result=error|<message>
#
# Battery, Bluetooth, Power Profile, and Do-Not-Disturb are NOT handled here:
# they come from Plasma's own QML modules (see ui/backends/). Only what is
# still hand-rolled lives in this file.
#
# Every lookup fails silently: a missing tool or device just means that
# feature is left out of the output, and the UI hides or disables it.
#
# Sources:  audio       wpctl (PipeWire/WirePlumber)
#           brightness  org.kde.ScreenBrightness (PowerDevil) on the session bus,
#                       falling back to /sys/class/backlight + logind SetBrightness
#           Wi-Fi       nmcli (NetworkManager)
#           nightcolor  org.kde.KWin.NightLight D-Bus + ~/.config/kwinrc
#           colorscheme plasma-apply-colorscheme + ~/.config/kdeglobals
#           airplane    rfkill

SYSFS=${QS_SYSFS:-/sys}
SINK='@DEFAULT_AUDIO_SINK@'
SOURCE='@DEFAULT_AUDIO_SOURCE@'
KDE_SVC=org.kde.ScreenBrightness
KDE_ROOT=/org/kde/ScreenBrightness
ESC=$(printf '\033')

have() { command -v "$1" >/dev/null 2>&1; }

# Print one line verbatim. Never use `echo` for data: dash's echo turns
# sequences like \2 or \c in a Wi-Fi name or device alias into control bytes.
out() { printf '%s\n' "$*"; }

# only digits and a dot: guards everything we pass on to other programs
is_fraction() {
    case $1 in
        ''|*[!0-9.]*|*.*.*) return 1 ;;
    esac
    return 0
}

# nmcli wrapper:
#  - LC_ALL=C so their output is never translated (we match on English words)
#  - </dev/null so it can't swallow the input of a surrounding `while read`
#  - timeout (when available) so a stuck daemon can't hang the plasmoid
nm() {
    if have timeout; then
        LC_ALL=C timeout 10 nmcli "$@" </dev/null
    else
        LC_ALL=C nmcli "$@" </dev/null
    fi
}
# connecting can legitimately take a while (nmcli itself gives up after -w 25)
nm_slow() {
    if have timeout; then
        LC_ALL=C timeout 40 nmcli "$@" </dev/null
    else
        LC_ALL=C nmcli "$@" </dev/null
    fi
}
strip_ansi() { sed "s/$ESC\[[0-9;]*[A-Za-z]//g"; }

# nmcli terse mode escapes ':' and '\' with a backslash
nm_unescape() { sed 's/\\\(.\)/\1/g'; }

# ------------------------------------------------------------------ audio
audio_state() { # $1 = key prefix, $2 = wpctl target
    have wpctl || return 0
    out=$(wpctl get-volume "$2" 2>/dev/null) || return 0
    vol=$(printf '%s\n' "$out" | sed -n 's/^Volume:[[:space:]]*\([0-9.][0-9.]*\).*/\1/p')
    [ -n "$vol" ] || return 0
    case $out in
        *MUTED*) muted=1 ;;
        *) muted=0 ;;
    esac
    out "$1_volume=$vol"
    out "$1_muted=$muted"
}

# ------------------------------------------------------------ audio devices
# Device list for the picker arrows at the right edge of the volume and
# microphone sliders (GNOME quick settings style).  Emit key-value lines
# shaped like every other helper:
#     sinkjson=[["alsa_output...",1,"Built-in Audio Analog Stereo"],...]
# (index 1 in each triple means "is the default device").  pactl is part
# of the pulseaudio-utils package pipewire-pulse setups ship alongside,
# and its JSON mode reports names, descriptions and the default directly,
# so no wpctl status tree parsing is needed.
audio_list() { # $1 = pactl kind ("sinks"|"sources"), $2 = emit key ("sink"|"source")
    have pactl || { out "result=error|pactl is not installed"; return 0; }
    JSON=$(pactl -f json list "$1" 2>/dev/null | python3 -c '
import json, subprocess, sys
kind, key = sys.argv[1], sys.argv[2]
info_key = "default_sink_name" if kind == "sinks" else "default_source_name"
default = ""
try:
    info = subprocess.run(["pactl", "-f", "json", "info"], capture_output=True, text=True, timeout=5)
    default = json.loads(info.stdout).get(info_key, "")
except (OSError, ValueError):
    default = ""
try:
    devices = json.loads(sys.stdin.read())
except ValueError:
    devices = []
entries = []
for d in devices if isinstance(devices, list) else []:
    name = d.get("name", "")
    if not name:
        continue
    desc = d.get("description", "") or name
    entries.append([name, 1 if name == default else 0, desc])
print(key + "json=" + json.dumps(entries))
' "$1" "$2" 2>/dev/null)
    [ -n "$JSON" ] && out "$JSON"
}

# ------------------------------------------------------------- brightness
# Prefer the built-in display, otherwise the first one PowerDevil knows.
kde_display() {
    have busctl || return 1
    names=$(busctl --user get-property "$KDE_SVC" "$KDE_ROOT" "$KDE_SVC" DisplaysDBusNames 2>/dev/null) || return 1
    first=
    for tok in $names; do
        case $tok in
            \"*\")
                n=${tok#\"}
                n=${n%\"}
                [ -z "$first" ] && first=$n
                internal=$(busctl --user get-property "$KDE_SVC" "$KDE_ROOT/$n" "$KDE_SVC.Display" IsInternal 2>/dev/null)
                if [ "$internal" = "b true" ]; then
                    out "$n"
                    return 0
                fi
                ;;
        esac
    done
    [ -n "$first" ] || return 1
    out "$first"
}

kde_prop() { # $1 = display, $2 = property
    busctl --user get-property "$KDE_SVC" "$KDE_ROOT/$1" "$KDE_SVC.Display" "$2" 2>/dev/null | awk '{print $2}'
}

backlight_dev() {
    for d in "$SYSFS"/class/backlight/*; do
        if [ -r "$d/brightness" ] && [ -r "$d/max_brightness" ]; then
            out "$d"
            return 0
        fi
    done
    return 1
}

calc_target() { # $1 = fraction, $2 = max
    awk -v f="$1" -v m="$2" 'BEGIN { t = int(f * m + 0.5); if (t < 1) t = 1; if (t > m) t = m; print t }'
}

brightness_state() {
    if n=$(kde_display); then
        b=$(kde_prop "$n" Brightness)
        m=$(kde_prop "$n" MaxBrightness)
        if [ -n "$b" ] && [ "${m:-0}" -gt 0 ] 2>/dev/null; then
            out "brightness=$b"
            out "brightness_max=$m"
            return 0
        fi
    fi
    if d=$(backlight_dev); then
        out "brightness=$(cat "$d/brightness")"
        out "brightness_max=$(cat "$d/max_brightness")"
    fi
}

set_brightness() { # $1 = fraction 0..1
    if n=$(kde_display); then
        m=$(kde_prop "$n" MaxBrightness)
        if [ "${m:-0}" -gt 0 ] 2>/dev/null; then
            target=$(calc_target "$1" "$m")
            # the argument signature isn't documented; read it from introspection
            sig=$(busctl --user introspect "$KDE_SVC" "$KDE_ROOT/$n" "$KDE_SVC.Display" 2>/dev/null |
                awk '$1 == ".SetBrightness" { print $3; exit }')
            case $sig in
                i) busctl --user call "$KDE_SVC" "$KDE_ROOT/$n" "$KDE_SVC.Display" SetBrightness i "$target" ;;
                *) busctl --user call "$KDE_SVC" "$KDE_ROOT/$n" "$KDE_SVC.Display" SetBrightness iu "$target" 0 ;;
            esac
            return
        fi
    fi
    if d=$(backlight_dev) && have busctl; then
        target=$(calc_target "$1" "$(cat "$d/max_brightness")")
        busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
            org.freedesktop.login1.Session SetBrightness ssu backlight "${d##*/}" "$target"
    fi
}

# ------------------------------------------------------------------ Wi-Fi
wifi_state() {
    have nmcli || return 0
    status=$(nm -t -f DEVICE,TYPE,STATE device status 2>/dev/null) || return 0
    [ -n "$status" ] || return 0

    # DEVICE:TYPE:STATE  (P2P devices have type "wifi-p2p", so they don't match)
    present=$(printf '%s\n' "$status" | awk -F: '$2 == "wifi" { print 1; exit }')
    eth=$(printf '%s\n' "$status" | awk -F: '$2 == "ethernet" && $3 ~ /^connected/ { print 1; exit }')
    out "eth_connected=${eth:-0}"
    out "wifi_present=${present:-0}"
    [ -n "$present" ] || return 0

    case $(nm radio wifi 2>/dev/null) in
        enabled) out "wifi_enabled=1" ;;
        *) out "wifi_enabled=0"; return 0 ;;   # radio off: any cached list is stale
    esac

    # cached list (no rescan): the row marked with * is the active network
    nm -t -f IN-USE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null |
    while IFS= read -r line; do
        case $line in
            '*:'*)
                rest=${line#*:}
                signal=${rest%%:*}
                ssid=$(printf '%s' "${rest#*:}" | nm_unescape)
                out "wifi_signal=$signal"
                out "wifi_ssid=$ssid"
                break
                ;;
        esac
    done
}

# net=<in use 0/1>|<signal>|<security 0/1/2>|<saved 0/1>|<ssid>
wifi_list() {
    have nmcli || return 0
    saved=$(nm -t -f NAME,TYPE connection show 2>/dev/null |
        awk -F: '$NF == "802-11-wireless" { sub(/:802-11-wireless$/, ""); print }' | nm_unescape)
    nm -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null |
    while IFS= read -r line; do
        inuse=${line%%:*}
        rest=${line#*:}
        signal=${rest%%:*}
        rest=${rest#*:}
        security=${rest%%:*}
        ssid=$(printf '%s' "${rest#*:}" | nm_unescape)
        [ -n "$ssid" ] || continue            # hidden network
        case $inuse in '*') u=1 ;; *) u=0 ;; esac
        # 0 = open, 1 = password (WPA/WEP/OWE...), 2 = enterprise (needs a login)
        case $security in ''|'--') s=0 ;; *802.1X*) s=2 ;; *) s=1 ;; esac
        if printf '%s\n' "$saved" | grep -Fxq -- "$ssid"; then k=1; else k=0; fi
        out "net=$u|$signal|$s|$k|$ssid"
    done
}

# Report the outcome of an nmcli/bluetoothctl action in one line.
report() { # $1 = exit status, $2 = captured output
    if [ "$1" -eq 0 ]; then
        out "result=ok"
    else
        msg=$(printf '%s\n' "$2" | strip_ansi | sed -n '/[^[:space:]]/{s/^Error: //;p;q;}')
        out "result=error|${msg:-Something went wrong}"
    fi
}

# A failed first attempt with a wrong password still leaves NetworkManager with a
# saved profile holding that bad key, which would then fail forever as a "saved"
# network. Remove the Wi-Fi profile(s) named exactly $1.
forget_wifi() {
    nm -t -f NAME,UUID,TYPE connection show 2>/dev/null |
    while IFS= read -r l; do
        type=${l##*:}
        rest=${l%:*}
        uuid=${rest##*:}
        name=$(printf '%s' "${rest%:*}" | nm_unescape)
        [ "$type" = 802-11-wireless ] || continue
        [ "$name" = "$1" ] || continue
        nm connection delete uuid "$uuid" >/dev/null 2>&1
    done
}

wifi_connect() { # $1 = ssid, $2 = saved|new, [$3 = password]
    have nmcli || { out "result=error|NetworkManager is not available"; return; }
    case $2 in
        saved)
            out=$(nm_slow -w 25 connection up id "$1" 2>&1)
            report $? "$out"
            return
            ;;
    esac
    case $1 in
        -*) out "result=error|Names starting with \"-\" aren't supported here. Use System Settings."; return ;;
    esac
    if [ $# -ge 3 ]; then
        out=$(nm_slow -w 25 device wifi connect "$1" password "$3" 2>&1)
        rc=$?
        if [ $rc -ne 0 ]; then
            case $out in
                *"Secrets were required"*|*"No valid secrets"*|*"Invalid secrets"*) forget_wifi "$1" ;;
            esac
        fi
    else
        out=$(nm_slow -w 25 device wifi connect "$1" 2>&1)
        rc=$?
    fi
    report $rc "$out"
}

wifi_disconnect() {
    dev=$(nm -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')
    [ -n "$dev" ] || { out "result=ok"; return; }
    out=$(nm device disconnect "$dev" 2>&1)
    report $? "$out"
}

# ---------------------------------------------------------------- actions
# Start a GUI program fully detached so it outlives this script.
detach() { (setsid "$@" >/dev/null 2>&1 &); }

# ----------------------------------------------------------- Night Color
# KWin exposes org.kde.KWin.NightLight on the session bus at
# /org/kde/KWin/NightLight with properties `available`, `enabled`, `running`
# and method `reconfigure()`.  We toggle by writing kwinrc and asking KWin
# to re-read it (same path the KCM uses).
KWIN_SVC=org.kde.KWin
KWIN_NCL_PATH=/org/kde/KWin/NightLight
KWIN_NCL_IFACE=org.kde.KWin.NightLight

# Read one NightLight property (returns "true"/"false"/"" on stdout).
nc_prop() { # $1 = property name
    have busctl || return 0
    busctl --user get-property "$KWIN_SVC" "$KWIN_NCL_PATH" "$KWIN_NCL_IFACE" "$1" 2>/dev/null \
        | awk '{print $2}'
}

nightcolor_state() {
    have busctl || return 0
    # If the KWin service or the NightLight interface isn't there, treat as
    # unavailable — `available=false` makes the UI hide the tile.
    avail=$(nc_prop available)
    [ "$avail" = "true" ] || { out "nc_available=0"; return 0; }
    out "nc_available=1"
    out "nc_enabled=$(nc_prop enabled)"
    out "nc_running=$(nc_prop running)"
}

# Write kwinrc [NightColor] Active=<bool> then ask KWin to reload.
# kwriteconfig6/kreadconfig6 are part of KDE Frameworks and always present
# on a Plasma 6 system; if they're missing we fall back to a manual edit.
kwriteconfig_kwinrc() { # $1 = key, $2 = value
    if have kwriteconfig6; then
        kwriteconfig6 --file kwinrc --group NightColor --key "$1" "$2"
    else
        # Manual fallback: rewrite the [NightColor] section of ~/.config/kwinrc.
        cfg=${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc
        tmp=$(mktemp)
        awk -v k="$1" -v v="$2" '
            BEGIN { in_grp=0; wrote=0 }
            /^\[/{ in_grp = ($0 == "[NightColor]") }
            {
                if (in_grp && $0 ~ "^"k"=") { print k"="v; wrote=1; next }
                print
            }
            END { if (!wrote && in_grp) print k"="v }
        ' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    fi
}

nightcolor_set() { # $1 = on|off
    case $1 in
        on) val=true ;;
        off) val=false ;;
        *) return 2 ;;
    esac
    kwriteconfig_kwinrc Active "$val"
    # Tell KWin to re-read kwinrc.
    if have busctl; then
        busctl --user call "$KWIN_SVC" "$KWIN_NCL_PATH" "$KWIN_NCL_IFACE" reconfigure 2>/dev/null
    fi
    out "result=ok"
}

# --------------------------------------------------------- Color scheme
# plasma-apply-colorscheme is the official Plasma 6 way to switch themes.
# It writes kdeglobals, notifies running apps, and updates the KColorScheme
# cache.  We read the current name from kdeglobals directly (cheap, no fork).
KDEGLOBALS=${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals
COLOR_DIRS="/usr/share/color-schemes:${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"

colorscheme_current() {
    if have kreadconfig6; then
        kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null
    elif [ -r "$KDEGLOBALS" ]; then
        awk -F= '/^\[General\]/{g=1; next} /^\[/{g=0} g && $1=="ColorScheme"{sub(/^[^=]*=/,""); print; exit}' "$KDEGLOBALS"
    fi
}

# Print every installed scheme name, one per line.  A .colors file's name is
# the user-visible scheme name; the [General] Name= key inside is only the
# display label, so we use the filename (without extension) as the canonical
# id — same convention as plasma-apply-colorscheme.
colorscheme_list() {
    have plasma-apply-colorscheme || return 0
    IFS=:
    for d in $COLOR_DIRS; do
        [ -d "$d" ] || continue
        for f in "$d"/*.colors; do
            [ -r "$f" ] || continue
            b=${f##*/}
            printf '%s\n' "${b%.colors}"
        done
    done
    unset IFS
}

colorscheme_state() {
    have plasma-apply-colorscheme || { out "cs_available=0"; return 0; }
    out "cs_available=1"
    out "cs_current=$(colorscheme_current)"
    # Tab-separated list — newlines would break parseKv().
    list=$(colorscheme_list | tr '\n' '\t')
    out "cs_list=$list"
}

colorscheme_set() { # $1 = scheme name
    have plasma-apply-colorscheme || { out "result=error|plasma-apply-colorscheme is not installed"; return; }
    [ -n "$1" ] || { out "result=error|No scheme name given"; return; }
    # plasma-apply-colorscheme exits non-zero on unknown schemes; capture its
    # message (it prints to stdout, not stderr).
    msg=$(plasma-apply-colorscheme "$1" 2>&1)
    rc=$?
    if [ $rc -eq 0 ]; then
        out "result=ok"
    else
        # The tool prints a multi-line help message on bad input; the first
        # non-empty line is the actual error.
        msg=$(printf '%s\n' "$msg" | sed -n '/[^[:space:]]/{s/^Error: //;p;q;}')
        out "result=error|${msg:-Could not apply color scheme}"
    fi
}

# ----------------------------------------------------------- Airplane mode
# rfkill is the same kernel interface Plasma's airplane-mode indicator uses
# internally.  "Airplane on" = soft-block every radio.  We don't touch hard
# blocks — those come from the physical switch and can't be changed from
# software.

airplane_state() {
    have rfkill || { out "air_available=0"; return 0; }
    # `--raw --noheadings` makes the output tab-separated with no header row.
    # Both flags have been in util-linux since 2.27 (2015); `--output` for
    # `rfkill list` is newer (2.36, 2020).  If the installed rfkill is too
    # old to know `--output`, the command fails and we report unavailable —
    # which is the graceful-degradation behaviour the UI expects.
    rfk=$(rfkill list --output TYPE,SOFT,HARD --noheadings --raw 2>/dev/null) \
        || { out "air_available=0"; return 0; }
    [ -n "$rfk" ] || { out "air_available=0"; return 0; }
    out "air_available=1"
    # A radio is "soft-blockable" if it has a soft-block field at all.  We're
    # "in airplane mode" when every soft-blockable radio is soft-blocked.
    # `hard=blocked` on any radio means a physical switch is off — we report
    # that separately so the UI can mark the tile as hardware-disabled.
    soft_total=0
    soft_blocked=0
    hard_blocked=0
    while IFS=$'\t' read -r type soft hard; do
        [ -n "$type" ] || continue
        case $soft in
            blocked) soft_blocked=$((soft_blocked + 1)); soft_total=$((soft_total + 1)) ;;
            unblocked) soft_total=$((soft_total + 1)) ;;
        esac
        case $hard in blocked) hard_blocked=1 ;; esac
    done <<EOF
$rfk
EOF
    out "air_hard=$hard_blocked"
    if [ "$soft_total" -gt 0 ] && [ "$soft_total" -eq "$soft_blocked" ]; then
        out "air_active=1"
    else
        out "air_active=0"
    fi
}

airplane_set() { # $1 = on|off
    have rfkill || { out "result=error|rfkill is not installed"; return; }
    case $1 in
        on) rfkill block all ;;
        off) rfkill unblock all ;;
        *) out "result=error|Bad argument"; return ;;
    esac
    out "result=ok"
}

# ----------------------------------------------- Tray: StatusNotifier + Background Apps
# The stock plasma-workspace systemtray is a ContainmentItem and can't be
# embedded; instead we talk to the same public D-Bus services its private
# models wrap:
#   - org.kde.StatusNotifierWatcher at /StatusNotifierWatcher
#       property  RegisteredStatusNotifierItems   (QStringList of "service/path")
#   - each item: org.kde.StatusNotifierItem at <service><path>
#       properties: Title, IconName, IconThemePath, ToolTip, ItemIsMenu
#       method:     Activate(int x, int y)   -- also SecondaryActivate, ContextMenu
#   - org.freedesktop.background.Monitor at /org/freedesktop/background/monitor
#       property  BackgroundApps   (list of {app_id, message, instance})
#       methods:   OpenApp(s app_id), StopApp(s instance)
#
# `busctl --user get-property` returns "as 4 'foo' 'bar'" for a string list;
# we strip the leading type+count and pull each quoted token.  For the
# per-item Title/IconName lookups we make one short busctl call per SNI
# (fine for a handful of tray icons; the stock systemtray does the same
# thing one level deeper in C++).

SNW_SVC=org.kde.StatusNotifierWatcher
SNW_PATH=/StatusNotifierWatcher
SNW_IFACE=org.kde.StatusNotifierWatcher
BG_SVC=org.freedesktop.background.Monitor
BG_PATH=/org/freedesktop/background/monitor
BG_IFACE=org.freedesktop.background.Monitor

# Print one quoted token per line from a busctl "as" property reply.
# We pass the double-quote character to awk via an env var (Q) so the awk
# script can stay single-quoted and we don't have to worry about shell
# quoting of the literal " inside the script.
busctl_string_list() { # $1 = service, $2 = path, $3 = iface, $4 = property
    have busctl || return 0
    busctl --user get-property "$1" "$2" "$3" "$4" 2>/dev/null \
        | Q='"' awk 'BEGIN { Q = ENVIRON["Q"] }
            {
                # busctl prints "as N \"item1\" \"item2\" ..."; we want each
                # item without its surrounding quotes.  Fields beyond $2 are
                # the items, but an item may contain spaces (e.g. an SNI
                # service "My App") — busctl keeps each item in one quoted
                # token, so we re-join them with a small state machine.
                for (i = 3; i <= NF; i++) {
                    line = $i
                    if (substr(line, 1, 1) == Q) line = substr(line, 2)
                    if (substr(line, length(line), 1) == Q) line = substr(line, 1, length(line) - 1)
                    if (line != "") print line
                }
            }'
}

# Print one busctl scalar property as a bare value (string with quotes
# stripped, bool as true/false, etc.).  Handles multi-word strings by
# taking the *rest of the line* after the type field, not just $2.
busctl_scalar() { # $1 = service, $2 = path, $3 = iface, $4 = property
    have busctl || return 0
    # Pass both the double-quote and a single-space chars as env vars so
    # the awk script can stay single-quoted without any literal " or
    # problematic shell metacharacters.
    busctl --user get-property "$1" "$2" "$3" "$4" 2>/dev/null \
        | Q='"' SP=' ' awk 'BEGIN { Q = ENVIRON["Q"]; SP = ENVIRON["SP"] }
            {
                # busctl format: "<type> <value>".  For "s" the value is
                # quoted; for "b" it is "true" or "false".  Take everything
                # after the first space so multi-word strings survive.
                p = index($0, SP)
                if (p == 0) { print ""; next }
                v = substr($0, p + 1)
                # Strip one leading quote if present.
                if (substr(v, 1, 1) == Q) v = substr(v, 2)
                # Strip one trailing quote if present.
                if (substr(v, length(v), 1) == Q) v = substr(v, 1, length(v) - 1)
                print v
            }'
}

# Render one SNI's IconPixmap (a(iiay)) to a PNG file and print its absolute
# path — the fallback the stock plasma tray uses when IconName/IconThemePath
# yield nothing.  IBus (ayatana proxied) and Plasma's Live Captions expose no
# IconName at all, only a bitmap, which is why their pills showed a generic
# "unknown" square instead of the real icon while the stock tray looked fine.
#
# Byte order per the StatusNotifierItem spec: ARGB32, big-endian bytes
# (b0=A, b1=R, b2=G, b3=B) — the same reading plasma-workspace's
# StatusNotifierItemSource does.  The PNG file name carries a CRC of the
# image bytes so QML sees a fresh URL whenever the icon content changes
# (e.g. IBus switching input methods); older files for the same item are
# pruned so the cache does not grow without bound.
sni_pixmap_icon() { # $1 = service, $2 = object path
    have busctl && have python3 || return 1
    cache=${XDG_CACHE_HOME:-$HOME/.cache}/quicksettings/sni-pix
    mkdir -p "$cache" 2>/dev/null || return 1
    # Drop icons not touched for a day (services are colon-id bus names that
    # churn when apps restart, so the md5 keys never repeat across sessions).
    find "$cache" -name "*.png" -mmin +1440 -delete 2>/dev/null
    key=$(printf '%s|%s' "$1" "$2" | md5sum | cut -c1-12)
    json=$(busctl --user call "$1" "$2" org.freedesktop.DBus.Properties Get ss \
        org.kde.StatusNotifierItem IconPixmap --json=short 2>/dev/null)
    [ -n "$json" ] || return 1

    printf '%s' "$json" | python3 -c '
import glob, json, os, struct, sys, zlib

class Hashed:  # writes path + keeps a running content crc
    def __init__(self, base):
        self.base = base
        self.images = 0
    def run(self):
        obj = json.load(sys.stdin) or {}
        data = obj.get("data", [])[0].get("data", [[]]) if isinstance(obj, dict) else []
        # data is [[w, h, [bytes...]], ...]  — pick the largest pixmap;
        # the stock tray does the same (livecaptions sends 5 of 16x16).
        pixmaps = [p for p in data if len(p) == 3 and isinstance(p[0], int) and isinstance(p[2], list)]
        pixmaps = [p for p in pixmaps if p[0] > 0 and p[1] > 0 and len(p[2]) >= p[0] * p[1]]
        if not pixmaps:
            sys.exit()
        w, h, raw = max(pixmaps, key=lambda p: p[0] * p[1])
        self.w, self.h = w, h
        self.raw = bytes(raw[:w * h * 4])
        self.crc = zlib.crc32(self.raw) & 0xFFFFFFFF
        self.path = "%s-%08x.png" % (self.base, self.crc)
        for old in glob.glob(self.base + "-*.png"):
            if old != self.path:
                try: os.unlink(old)
                except OSError: pass
    def write(self):
        body = bytearray()
        for y in range(self.h):
            body.append(0)  # filter: none, per scanline
            row_start = y * self.w * 4
            for x in range(self.w):
                i = row_start + x * 4
                a, r, g, b = self.raw[i], self.raw[i + 1], self.raw[i + 2], self.raw[i + 3]
                body += bytes((r, g, b, a))
        def chunk(t, d):
            import binascii
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", binascii.crc32(t + d) & 0xFFFFFFFF)
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(body))) + chunk(b"IEND", b"")
        open(self.path, "wb").write(png)  # noqa: SIM115 — process exits, no leak

h = Hashed(sys.argv[1])
h.run()
h.write()
print(h.path)
' "$cache/$key" 2>/dev/null || return 1
}

# Fetch all StatusNotifierItem properties for one SNI in a single D-Bus
# call (GetAll on org.freedesktop.DBus.Properties), then emit one
# "sni=..." line.  This mirrors what the plasma-workspace
# StatusNotifierItemSource does: it calls GetAll once and reads
# Title/IconName/IconPixmap/ToolTip/ItemIsMenu from the resulting map.
#
# Output: "sni=<title>|<icon>|<tooltip>|<isMenu>|<service>|<path>"
#
# busctl prints the GetAll reply as:
#   a{sv} N "Key1" <type-marker1> <value1> "Key2" <type-marker2> <value2> ...
# For string values: "Key" s "value"
# For bool values:   "Key" b true|false
# For the ToolTip struct: "ToolTip" (ii@ayss) N "icon" "title" "subtitle"
#
# We use a simple substring-search approach (find the quoted key, then
# parse the value that follows the type marker).  This is robust against
# multi-word values and structs we do not care about.
sni_describe() { # $1 = "service/path" pair from RegisteredStatusNotifierItems
    pair=$1
    case $pair in
        */*) svc=${pair%%/*}; path=/${pair#*/} ;;
        *)   svc=$pair;       path=/StatusNotifierItem ;;
    esac
    [ -n "$svc" ] && [ -n "$path" ] || return 0

    # Single D-Bus call to fetch all properties of this SNI.
    # Use --full so busctl does NOT ellipsize long values (the default
    # truncates long Title/ToolTip strings to "...", which is why every
    # row was showing the D-Bus service name as a fallback in v0.6.0).
    raw=$(busctl --user --full call "$svc" "$path" org.freedesktop.DBus.Properties GetAll s org.kde.StatusNotifierItem 2>/dev/null)
    [ -n "$raw" ] || {
        # The D-Bus call failed entirely (the SNI may have vanished, or the
        # service is unresponsive).  Emit a row with the service name as the
        # title so the user still sees *something* and can try clicking it.
        out "sni=${svc}|application-x-executable||0|${svc}|${path}"
        return 0
    }

    # extract_string PROPNAME  -- returns the value of a string property.
    # For non-string types (bool, struct) it returns the bare token after
    # the type marker, which is fine for ItemIsMenu (true/false).
    # The parser reads ALL of stdin into one buffer (in case busctl wraps
    # the GetAll reply across multiple physical lines for long values).
    Q='"'
    extract_string() {  # $1 = property name
        printf '%s\n' "$raw" | awk -v Q="$Q" -v want="$1" '
            BEGIN { buf = "" }
            { buf = buf $0 " " }
            END {
                s = buf
                # Find " want " as a quoted key (with surrounding spaces so
                # we do not match a substring of a longer key).
                needle = " " Q want Q " "
                i = index(s, needle)
                if (i == 0) { print ""; exit }
                # Skip past the key (and the space after it).
                rest = substr(s, i + length(needle))
                # Skip whitespace.
                while (substr(rest, 1, 1) == " ") rest = substr(rest, 2)
                # Next token is the type marker (s, b, (ii@ayss), etc.).
                sp = index(rest, " ")
                if (sp == 0) { print ""; exit }
                rest = substr(rest, sp + 1)
                # Skip whitespace.
                while (substr(rest, 1, 1) == " ") rest = substr(rest, 2)
                # For a string value the next char is a quote.
                if (substr(rest, 1, 1) == Q) {
                    closer = index(substr(rest, 2), Q)
                    if (closer == 0) { print ""; exit }
                    print substr(rest, 2, closer - 1)
                    exit
                }
                # Otherwise (bool, number, struct opener) return the bare word.
                sp = index(rest, " ")
                if (sp == 0) print rest
                else print substr(rest, 1, sp - 1)
            }'
    }

    # extract_tooltip  -- returns the title field of the ToolTip struct.
    # The struct layout is (icon-name, title, sub-title); busctl renders
    # the value as: (ii@ayss) N "icon" "title" "sub"  We want the second
    # quoted string (the title), skipping the icon-name.
    extract_tooltip() {
        printf '%s\n' "$raw" | awk -v Q="$Q" '
            BEGIN { buf = "" }
            { buf = buf $0 " " }
            END {
                s = buf
                # Find "ToolTip" as a quoted key.
                needle = " " Q "ToolTip" Q " "
                i = index(s, needle)
                if (i == 0) { print ""; exit }
                rest = substr(s, i + length(needle))
                # Walk forward collecting quoted strings; we want the 2nd
                # one (the title field — the 1st is the icon-name, which
                # is usually empty).
                n = 0
                len = length(rest)
                pos = 1
                while (pos <= len) {
                    ch = substr(rest, pos, 1)
                    if (ch == Q) {
                        closer = index(substr(rest, pos + 1), Q)
                        if (closer == 0) break
                        n++
                        if (n == 2) { print substr(rest, pos + 1, closer - 1); exit }
                        pos += closer + 1
                    } else {
                        pos++
                    }
                }
                print ""
            }'
    }

    TITLE=$(extract_string Title)
    ICON=$(extract_string IconName)
    ISMENU=$(extract_string ItemIsMenu)
    TOOLTIP=$(extract_tooltip)

    # busctl --full escapes non-printables, so a multiline Title (IBus
    # Panel: its full help text is part of the title) arrives as literal
    # "\n" characters — the pill then shows the whole help blob as its
    # label.  Keep only the real title line for the label; the rest goes
    # to the tooltip, newline-escaped as well (it is rendered on one line
    # there anyway).
    first_line() {
        printf '%s' "$1" | awk '
            { i = index($0, "\\n"); if (i > 0) print substr($0, 1, i - 1); else print; exit }'
    }
    XXX="$TITLE"
    TITLE=$(first_line "$TITLE")
    [ -n "$TITLE" ] || TITLE=$XXX

    # No usable theme icon?  Then try the IconPixmap bitmap, like the
    # stock tray does (IBus and Live Captions carry ONLY a pixmap).
    if [ -z "$ICON" ]; then
        ICON=$(sni_pixmap_icon "$svc" "$path")
        [ -n "$ICON" ] || ICON=$procname
    fi

    # PID-based fallback (matches what plasma-workspace's
    # StatusNotifierItemSource::resolveProcessName does, then takes the
    # process name as the title when neither Title nor ToolTip.title is
    # exposed by the SNI — common for X11 apps proxied via xembed-sni-proxy
    # and for some Electron apps that only set the chrome_status_icon Id).
    if [ -z "$TITLE" ] && have busctl; then
        pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$svc" 2>/dev/null \
            | awk '{ print $2 }')
        if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
            # Try /proc/PID/cmdline first for Electron apps: extract the
            # app name from the .asar path (e.g. /usr/lib/vesktop/app.asar
            # -> "vesktop").  cmdline is NUL-separated.
            asar=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null \
                | awk -F/ '/\.asar$/ { print $0; exit }')
            if [ -n "$asar" ]; then
                # Parent directory of the .asar file is the app name.
                procname=$(printf '%s' "$asar" | awk -F/ '{ print $(NF-1) }')
            else
                # Fallback to /proc/PID/comm (kernel-reported process name).
                procname=$(cat "/proc/$pid/comm" 2>/dev/null)
            fi
            if [ -n "$procname" ]; then
                TITLE=$procname
                # If IconName is also empty, try the process name as the
                # icon — Kirigami will fall back to a generic icon if the
                # theme doesn't have one by that name.  Many apps ship an
                # icon matching their executable name.
                [ -z "$ICON" ] && ICON=$procname
                [ -z "$TOOLTIP" ] && TOOLTIP=$TITLE
            fi
        fi
    fi

    # Normalise: empty Title falls back to the service name; empty Icon
    # falls back to a generic executable icon (Kirigami will find it).
    # The QML does NOT do its own fallback for these because the script is
    # the canonical source.
    [ -z "$TITLE" ] && TITLE=$svc
    [ -z "$ICON" ] && ICON=application-x-executable
    [ -z "$TOOLTIP" ] && TOOLTIP=$TITLE
    case "$ISMENU" in true|1) ISMENU=1 ;; *) ISMENU=0 ;; esac

    out "sni=${TITLE}|${ICON}|${TOOLTIP}|${ISMENU}|${svc}|${path}"
}

tray_state() {
    have busctl || { out "tray_available=0"; return 0; }
    # Is the watcher registered on the session bus?
    if ! busctl --user list 2>/dev/null | grep -q "^$SNW_SVC"; then
        out "tray_available=0"
        return 0
    fi
    out "tray_available=1"
    # List SNIs and describe each.
    busctl_string_list "$SNW_SVC" "$SNW_PATH" "$SNW_IFACE" RegisteredStatusNotifierItems \
        | while IFS= read -r pair; do
            [ -n "$pair" ] && sni_describe "$pair"
        done

    # Background apps — same D-Bus pattern, different service.
    out "bg_separator=1"
    if busctl --user list 2>/dev/null | grep -q "^$BG_SVC"; then
        out "bg_available=1"
        # BackgroundApps is "aa{sv}": one dict per app with the keys
        # app_id / instance / message.  busctl prints it as
        #   aa{sv} N M "app_id" s "x" "instance" s "y" "message" s "z" ...
        # Splitting on '"' gives key, " s ", value, " " repeating, so we walk
        # key/value pairs and emit one "bg_app=appid|instance|message" line
        # each time a new "app_id" key starts.
        busctl --user --full get-property "$BG_SVC" "$BG_PATH" "$BG_IFACE" BackgroundApps 2>/dev/null \
            | awk -F '"' '
                function flush() {
                    if (app != "") print "bg_app=" app "|" (inst != "" ? inst : app) "|" msg
                    app = ""; inst = ""; msg = ""
                }
                BEGIN { app = ""; inst = ""; msg = "" }
                {
                    for (i = 2; i + 2 <= NF; i += 4) {
                        k = $i; v = $(i + 2)
                        if (k == "app_id")        { flush(); app = v }
                        else if (k == "instance") { inst = v }
                        else if (k == "message")  { msg = v }
                    }
                }
                END { flush() }'
    else
        out "bg_available=0"
    fi
}

# Activate a StatusNotifierItem (left-click in the stock tray).
tray_activate() { # $1 = service, $2 = path
    have busctl || { out "result=error|busctl is not installed"; return; }
    [ -n "$1" ] && [ -n "$2" ] || { out "result=error|Missing service/path"; return; }
    # Some SNIs expose Activate on org.kde.StatusNotifierItem, some on the
    # older com.canonical.dbusmenu path; try the KDE name first.
    busctl --user call "$1" "$2" org.kde.StatusNotifierItem Activate ii 0 0 >/dev/null 2>&1 \
        && out "result=ok" \
        || out "result=error|Activate call failed"
}

# Show the SNI's context menu (right-click in the stock tray).
tray_context_menu() { # $1 = service, $2 = path
    have busctl || { out "result=error|busctl is not installed"; return; }
    busctl --user call "$1" "$2" org.kde.StatusNotifierItem ContextMenu ii 0 0 >/dev/null 2>&1 \
        && out "result=ok" \
        || out "result=error|ContextMenu call failed"
}

# --------------------------------------------------------------- DBusMenu ---
# The StatusNotifierHost (the stock tray) renders an item's menu itself:
# it reads `Menu` (an object path), walks that object's
# com.canonical.dbusmenu tree with GetLayout, shows the entries, and
# reports clicks with Event(id, "clicked", …).  Calling the SNI's own
# ContextMenu(0,0) — as this script used to do — does nothing for most
# items: the method is a no-op stub, the actual rendering is on us.
# These helpers give the QML side everything it needs to do that.

# Resolve an SNI's DBusMenu object path ("Menu" property).  Ayatana-style
# items can expose an empty Menu property while still serving the menu at
# the item's own path — GetLayout below tries the fallback.
tray_menu_object() { # $1 = service, $2 = sni path -> prints the path
    busctl --user get-property "$1" "$2" org.kde.StatusNotifierItem Menu 2>/dev/null \
        | awk '{ s = $NF; gsub(/"/, "", s); print s }'
}

tray_menu_layout() { # $1 = service, $2 = sni path
    have busctl || { out "menu_status=no-busctl"; return 0; }
    MP=$(tray_menu_object "$1" "$2")
    [ -z "$MP" ] && MP="$2"
    out "menu_status=ok"
    out "menu_path=$MP"

    # Restrict the properties we pull (icon-data entries are kilobytes of
    # PNG bytes we don't need); depth -1 asks the item once for the whole
    # tree, which works for ibus, Easy Effects, handy & friends even when
    # their submenus are built lazily (GetLayout answers the same way the
    # stock DBusMenuImporter results are built from).
    JSON=$(busctl --user call "$1" "$MP" com.canonical.dbusmenu GetLayout iias --json=short -- \
        0 -1 8 "label" "enabled" "visible" "icon-name" \
        "type" "children-display" "toggle-type" "toggle-state" 2>/dev/null)
    if [ -z "$JSON" ]; then
        # Some items only serve org.kde.dbusmenu (same layout on the wire).
        JSON=$(busctl --user call "$1" "$MP" org.kde.dbusmenu GetLayout iias --json=short -- \
            0 -1 8 "label" "enabled" "visible" "icon-name" \
            "type" "children-display" "toggle-type" "toggle-state" 2>/dev/null)
    fi
    if [ -z "$JSON" ]; then
        out "menu_status=error"
        return 0
    fi
    # busctl --json=short prints one line; JSON.parse() on the QML side takes it.
    out "menujson=$JSON"
}

# Activate a menu entry (what DBusMenuImporter sends when a user clicks).
tray_menu_click() { # $1 = service, $2 = menu path, $3 = entry id
    have busctl || { out "result=error|busctl is not installed"; return; }
    busctl --user call "$1" "$2" com.canonical.dbusmenu Event isvu -- \
        "$3" clicked v "s" "" 0 >/dev/null 2>&1 \
        && out "result=ok" \
        || out "result=error|Menu Event call failed"
}

# Let lazily-built subtrees refresh (e.g. ibus, apps building menus on demand).
tray_menu_about() { # $1 = service, $2 = menu path, $3 = entry id
    have busctl || return 0
    busctl --user call "$1" "$2" com.canonical.dbusmenu AboutToShow i -- "$3" >/dev/null 2>&1
}

# Open a background app's main window.
tray_open_app() { # $1 = app_id
    have busctl || { out "result=error|busctl is not installed"; return; }
    [ -n "$1" ] || { out "result=error|Missing app_id"; return; }
    busctl --user call "$BG_SVC" "$BG_PATH" "$BG_IFACE" OpenApp s "$1" >/dev/null 2>&1 \
        && out "result=ok" \
        || out "result=error|OpenApp call failed"
}

# Stop a background app instance.
tray_stop_app() { # $1 = instance
    have busctl || { out "result=error|busctl is not installed"; return; }
    [ -n "$1" ] || { out "result=error|Missing instance"; return; }
    busctl --user call "$BG_SVC" "$BG_PATH" "$BG_IFACE" StopApp s "$1" >/dev/null 2>&1 \
        && out "result=ok" \
        || out "result=error|StopApp call failed"
}

cmd=$1
arg=$2

case $cmd in
    poll)
        audio_state sink "$SINK"
        audio_state source "$SOURCE"
        brightness_state
        ;;
    netpoll)
        wifi_state
        ;;
    volume)
        is_fraction "$arg" || exit 2
        wpctl set-volume "$SINK" "$arg" -l 1.0 && wpctl set-mute "$SINK" 0
        ;;
    micvolume)
        is_fraction "$arg" || exit 2
        wpctl set-volume "$SOURCE" "$arg" -l 1.0 && wpctl set-mute "$SOURCE" 0
        ;;
    mute)
        case $arg in
            sink) wpctl set-mute "$SINK" toggle ;;
            source) wpctl set-mute "$SOURCE" toggle ;;
            *) exit 2 ;;
        esac
        ;;
    audiosinks)
        audio_list sinks sink
        ;;
    audiosources)
        audio_list sources source
        ;;
    setsink)
        [ -n "$arg" ] || exit 2
        pactl set-default-sink "$arg"
        ;;
    setsource)
        [ -n "$arg" ] || exit 2
        pactl set-default-source "$arg"
        ;;
    brightness)
        is_fraction "$arg" || exit 2
        set_brightness "$arg"
        ;;
    wifi)
        case $arg in on|off) ;; *) exit 2 ;; esac
        nm radio wifi "$arg" >/dev/null 2>&1
        ;;
    wifiscan)
        nm device wifi rescan >/dev/null 2>&1
        ;;
    wifilist)
        wifi_list
        ;;
    wificonnect)
        [ -n "$arg" ] || exit 2
        case $3 in saved|new) ;; *) exit 2 ;; esac
        wifi_connect "$arg" "$3"
        ;;
    wificonnectpw)
        [ -n "$arg" ] && [ -n "$3" ] || exit 2
        wifi_connect "$arg" new "$3"
        ;;
    wifidisconnect)
        wifi_disconnect
        ;;
    miscpoll)
        nightcolor_state
        airplane_state
        ;;
    cschemepoll)
        colorscheme_state
        ;;
    nightcolor)
        case $arg in on|off) ;; *) exit 2 ;; esac
        nightcolor_set "$arg"
        ;;
    colorscheme)
        case $arg in
            current) colorscheme_current ;;
            list) colorscheme_list ;;
            set) [ -n "$3" ] || exit 2; colorscheme_set "$3" ;;
            *) exit 2 ;;
        esac
        ;;
    airplane)
        case $arg in on|off) ;; *) exit 2 ;; esac
        airplane_set "$arg"
        ;;
    traypoll)
        tray_state
        ;;
    trayactivate)
        [ -n "$arg" ] && [ -n "$3" ] || exit 2
        tray_activate "$arg" "$3"
        ;;
    traymenu)
        [ -n "$arg" ] && [ -n "$3" ] || exit 2
        tray_context_menu "$arg" "$3"
        ;;
    traymenulayout)
        [ -n "$arg" ] && [ -n "$3" ] || exit 2
        tray_menu_layout "$arg" "$3"
        ;;
    traymenuclick)
        [ -n "$arg" ] && [ -n "$3" ] && [ -n "$4" ] || exit 2
        tray_menu_click "$arg" "$3" "$4"
        ;;
    traymenuabout)
        [ -n "$arg" ] && [ -n "$3" ] && [ -n "$4" ] || exit 2
        tray_menu_about "$arg" "$3" "$4"
        ;;
    trayopenapp)
        [ -n "$arg" ] || exit 2
        tray_open_app "$arg"
        ;;
    traystopapp)
        [ -n "$arg" ] || exit 2
        tray_stop_app "$arg"
        ;;
    lock)
        loginctl lock-session
        ;;
    power)
        # KDE's own "Shut Down / Restart / Log Out" dialog
        busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptAll
        ;;
    screenshot)
        # qs.sh screenshot [mode] [backend]
        #   mode:    fullscreen (default) | region | window
        #   backend: auto (default) | spectacle | grim | flameshot
        #            | gnome-screenshot | maim
        #
        # "auto" picks the first installed tool.  The CLI for each tool:
        #   spectacle:        -b -f | -b -r | -b -m  (background, full/region/window-under-cursor)
        #   grim + slurp:     grim | slurp | grim -g "$(slurp)" | grim -g "$(slurp -w)"  (Wayland)
        #   flameshot:        full | gui | screen  (gui lets user pick region; -p saves to file)
        #   gnome-screenshot: -f | -a | -w  (fullscreen / area / window)
        #   maim:             (none) | -s | -i $(xdotool getactivewindow)  (X11)
        #
        # The mode→flag mapping for each backend is below.  Backends that
        # don't support a mode fall back to their default capture (e.g.
        # flameshot always launches the GUI for region, but for fullscreen
        # uses `flameshot full`).
        mode=${arg:-fullscreen}
        backend=${3:-auto}
        case "$mode" in
            fullscreen|region|window) ;;
            *) mode=fullscreen ;;
        esac

        # Resolve "auto" to the first installed backend.
        if [ "$backend" = auto ]; then
            if have spectacle; then backend=spectacle
            elif have grim && have slurp; then backend=grim
            elif have flameshot; then backend=flameshot
            elif have gnome-screenshot; then backend=gnome-screenshot
            elif have maim; then backend=maim
            else
                # Nothing installed — try spectacle anyway so the user sees
                # the standard "command not found" error in the journal.
                backend=spectacle
            fi
        fi

        # Build the command for the chosen backend+mode.  Each is detached
        # with a short delay so the popup has closed before the capture.
        case "$backend" in
            spectacle)
                case "$mode" in
                    fullscreen) flags="-b -f" ;;
                    region)     flags="-b -r" ;;
                    window)     flags="-b -m" ;;
                esac
                detach sh -c "sleep 0.5; exec spectacle $flags"
                ;;
            grim)
                # Wayland.  region uses slurp for selection; window uses
                # slurp -w (pick a window).  grim always saves to a file —
                # we write to XDG_PICTURES_DIR/screenshot-<timestamp>.png.
                pic_dir=${XDG_PICTURES_DIR:-$HOME/Pictures}
                [ -d "$pic_dir" ] || pic_dir=$HOME
                out_file="$pic_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
                case "$mode" in
                    fullscreen)
                        detach sh -c "sleep 0.5; exec grim '$out_file'"
                        ;;
                    region)
                        detach sh -c "sleep 0.5; exec grim -g \"\$(slurp)\" '$out_file'"
                        ;;
                    window)
                        detach sh -c "sleep 0.5; exec grim -g \"\$(slurp -w)\" '$out_file'"
                        ;;
                esac
                ;;
            flameshot)
                # flameshot has no "window under cursor" mode — region and
                # window both open the GUI picker.
                case "$mode" in
                    fullscreen) detach sh -c "sleep 0.5; exec flameshot full" ;;
                    *)          detach sh -c "sleep 0.5; exec flameshot gui" ;;
                esac
                ;;
            gnome-screenshot)
                case "$mode" in
                    fullscreen) flag="-f" ;;
                    region)     flag="-a" ;;
                    window)     flag="-w" ;;
                esac
                detach sh -c "sleep 0.5; exec gnome-screenshot $flag"
                ;;
            maim)
                case "$mode" in
                    fullscreen) flags="" ;;
                    region)     flags="-s" ;;
                    window)     flags="-i \$(xdotool getactivewindow)" ;;
                esac
                pic_dir=${XDG_PICTURES_DIR:-$HOME/Pictures}
                [ -d "$pic_dir" ] || pic_dir=$HOME
                out_file="$pic_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
                detach sh -c "sleep 0.5; exec maim $flags '$out_file'"
                ;;
            *)
                # Unknown backend — fall back to spectacle so the user sees
                # a sensible error if it's missing.
                detach sh -c "sleep 0.5; exec spectacle -b -f"
                ;;
        esac
        ;;
    settings)
        case $arg in
            network) detach systemsettings kcm_networkmanagement ;;
            bluetooth) detach systemsettings kcm_bluetooth ;;
            power) detach systemsettings kcm_powerdevilprofilesconfig ;;
            notifications) detach systemsettings kcm_notifications ;;
            nightcolor) detach systemsettings kcm_nightcolor ;;
            colors) detach systemsettings kcm_colors ;;
            virtualkeyboard) detach systemsettings kcm_virtualkeyboard ;;
            removabledevices) detach systemsettings kcm_removabledevices ;;
            '') detach systemsettings ;;
            *) exit 2 ;;
        esac
        ;;
    *)
        printf 'unknown command: %s\n' "$cmd" >&2
        exit 2
        ;;
esac
exit 0
