#!/bin/bash
set -euo pipefail
root=$(pwd)
out="$root/we826q/package/files"
cd tailscale-src
test "$(git describe --tags --exact-match)" = v1.104.7
# Generate tags on the host BEFORE setting cross-compilation environment.
tags=$(env -u GOOS -u GOARCH -u GOMIPS CGO_ENABLED=0 go run ./cmd/featuretags --min --add=cli,osrouter,nattraversal,dns,advertiseroutes,useroutes,portmapper,ipnbus,health,iptables,bakedroots)
printf '%s\n' "$tags" > "$root/diagnostics/tailscale-tags.txt"
CGO_ENABLED=0 GOOS=linux GOARCH=mips GOMIPS=softfloat go build -p=2 -trimpath -tags="$tags" -ldflags='-s -w' -o "$root/tailscale-multicall" ./cmd/tailscaled
file "$root/tailscale-multicall" | tee "$root/diagnostics/tailscale-elf.txt"
file "$root/tailscale-multicall" | grep -q 'MSB.*MIPS'
sha256sum "$root/tailscale-multicall" | cut -d ' ' -f1 > "$out/tailscale.sha256"
xz --threads=1 --lzma2=dict=1MiB -c "$root/tailscale-multicall" > "$out/tailscale-multicall.xz"
xz --test "$out/tailscale-multicall.xz"
