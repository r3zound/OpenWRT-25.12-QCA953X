#!/bin/sh
set -eu
umask 077
source_dir=/usr/libexec/we826q-tailscale
cache=/tmp/we826q-tailscale
# Refuse pre-created symlinks and foreign-owned cache directories.
if [ ! -e "$cache" ]; then mkdir -m 700 "$cache" 2>/dev/null || :; fi
[ -d "$cache" ] && [ ! -L "$cache" ] && [ "$(stat -c %u "$cache")" = 0 ] || exit 1
chmod 700 "$cache"
expected=$(cat "$source_dir/tailscale.sha256")
valid() {
    [ -f "$cache/multicall" ] && [ ! -L "$cache/multicall" ] &&
        [ "$(sha256sum "$cache/multicall" | cut -d ' ' -f1)" = "$expected" ]
}
if ! valid; then
    tries=0
    while ! mkdir "$cache/lock" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -lt 120 ] || { echo 'Tailscale extraction lock timeout' >&2; exit 1; }
        sleep 1
    done
    tmp="$cache/new.$$"
    trap 'rm -f "$tmp"; rmdir "$cache/lock" 2>/dev/null || :' EXIT
    trap 'exit 1' HUP INT TERM
    if ! valid; then
        xz -dc "$source_dir/tailscale-multicall.xz" > "$tmp"
        [ "$(sha256sum "$tmp" | cut -d ' ' -f1)" = "$expected" ] || exit 1
        chmod 700 "$tmp"
        mv -f "$tmp" "$cache/multicall"
    fi
    rmdir "$cache/lock"
    trap - EXIT HUP INT TERM
fi
case "${0##*/}" in
    tailscale) export TS_BE_CLI=1 ;;
    tailscaled) export TS_BE_CLI=0 ;;
    *) echo 'invoke as tailscale or tailscaled' >&2; exit 1 ;;
esac
exec "$cache/multicall" "$@"
