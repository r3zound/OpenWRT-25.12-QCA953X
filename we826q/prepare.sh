#!/bin/bash
set -euo pipefail
root=$(pwd)
git init openwrt
cd openwrt
git remote add origin https://github.com/openwrt/openwrt.git
git fetch --depth=1 origin "$OPENWRT_COMMIT"
git checkout --detach FETCH_HEAD
test "$(git rev-parse HEAD)" = "$OPENWRT_COMMIT"
# The exact upstream commit is the release authority.
git apply --check "$root/we826q/board.patch"
git apply "$root/we826q/board.patch"
# Stage the local package before feeds creates the package metadata cache.
cp -R "$root/we826q/package" package/we826q-tailscale
./scripts/feeds update -a
# Install only our package closure. Installing every unrelated LuCI app exposes
# the release feed's luci-app-weechat/weechat variant dependency cycle.
./scripts/feeds install luci-light luci-proto-modemmanager modemmanager frpc xz
test -f feeds/packages/net/frp/Makefile
grep -q 'BuildPackage,frpc' feeds/packages/net/frp/Makefile
./scripts/feeds list -s -f > "$root/diagnostics/feeds.conf"
mkdir -p files
cp -R "$root/we826q/files/." files/
chmod 755 files/etc/uci-defaults/90-we826q files/etc/init.d/we826q-modem-discover files/usr/sbin/we826q-modem-discover
mkdir -p files/etc/rc.d
ln -s ../init.d/we826q-modem-discover files/etc/rc.d/S95we826q-modem-discover
# No credentials or endpoint settings. Override any feed example config.
mkdir -p files/etc/config
printf "config frpc 'common'\n\toption enabled '0'\n" > files/etc/config/frpc
cp "$root/we826q/config.seed" .config
make defconfig
python3 "$root/we826q/check-config.py" .config
./scripts/diffconfig.sh > "$root/diagnostics/diffconfig"
