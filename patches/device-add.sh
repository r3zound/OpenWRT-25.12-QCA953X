#!/bin/bash
# ============================================================================
# device-add.sh - add edgelink_el-953 device support to Y0518/immortalwrt source
# Run after cloning source, before make.
# NOTE: modemfeed feed is added by the workflow (with ^commit pin), NOT here,
#       to avoid duplicate feed names breaking ./scripts/feeds update -a.
# Usage: in immortalwrt source root: bash ../device-add.sh
# ============================================================================
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-.}"

echo "[1/4] copy dts"
cp "$HERE/qca9531_edgelink_el-953.dts" "$SRC/target/linux/ath79/dts/"

echo "[2/4] append generic.mk Device block"
cat >> "$SRC/target/linux/ath79/image/generic.mk" <<'EOF'

define Device/edgelink_el-953
  $(Device/tplink-16mlzma)
  SOC := qca9531
  DEVICE_VENDOR := EdgeLink
  DEVICE_MODEL := EL-953
  IMAGE_SIZE := 16000k
  DEVICE_PACKAGES := kmod-usb2
  SUPPORTED_DEVICES += edgelink-el-953
endef
TARGET_DEVICES += edgelink_el-953
EOF

echo "[3/4] append 02_network case"
NET="$SRC/target/linux/ath79/generic/base-files/etc/board.d/02_network"
if ! grep -q "edgelink,el-953)" "$NET"; then
  python3 - "$NET" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "glinet,gl-x300b)"
add = '''\tedgelink,el-953)
\t\tucidef_set_interface_wan "usb0"
\t\tucidef_add_switch "switch0" \\
\t\t\t"0@eth0" "1:lan"
\t\t;;
'''
if anchor in s and "edgelink,el-953)" not in s:
    s = s.replace(anchor, add + anchor, 1)
    open(p, "w").write(s)
    print("inserted 02_network")
else:
    print("02_network: anchor not found or already present")
PYEOF
fi

echo "[4/4] append 01_leds case"
LEDS="$SRC/target/linux/ath79/generic/base-files/etc/board.d/01_leds"
if ! grep -q "edgelink,el-953)" "$LEDS"; then
  python3 - "$LEDS" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "glinet,gl-x300b)"
add = '''\tedgelink,el-953)
\t\tucidef_set_led_switch "lan" "LAN" "blue:lan1" "switch0" "0x02"
\t\tucidef_set_led_netdev "wan" "WAN" "blue:wan" "eth1"
\t\tucidef_set_led_wlan "wlan" "WLAN" "blue:wifi" "phy0tpt"
\t\t;;
'''
if anchor in s and "edgelink,el-953)" not in s:
    s = s.replace(anchor, add + anchor, 1)
    open(p, "w").write(s)
    print("inserted 01_leds")
else:
    print("01_leds: anchor not found or already present")
PYEOF
fi

echo "[5/5] add uci-defaults for 4G WAN (usb0 static)"
UCI="$SRC/target/linux/ath79/generic/base-files/etc/uci-defaults"
mkdir -p "$UCI"
cat > "$UCI/99-edgelink-4g" <<'EOF'
#!/bin/sh
# EdgeLink EL-953: default WAN over 4G ECM (usb0 static), drop bogus qmi/ncm
[ -e /etc/config/network ] || exit 0
uci set network.wan.proto='static'
uci set network.wan.device='usb0'
uci set network.wan.ipaddr='192.168.43.100'
uci set network.wan.netmask='255.255.255.0'
uci set network.wan.gateway='192.168.43.1'
uci set network.wan.metric='10'
uci -q delete network.wan6
uci -q delete network.wwan
uci commit network
# Static upstream DNS (ECM module does not provide DNS)
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='223.5.5.5'
uci add_list dhcp.@dnsmasq[0].server='119.29.29.29'
uci commit dhcp
# frpc: 服务器信息留空（删掉默认占位 server_addr 与示例代理）
if [ -f /etc/config/frpc ]; then
  while uci -q delete frpc.@conf[0]; do :; done
  uci commit frpc
fi
exit 0
EOF
chmod +x "$UCI/99-edgelink-4g"

echo "[6/6] inject rc.local: force eth0/LAN up + boot diag log"
RC="$SRC/target/linux/ath79/generic/base-files/etc/rc.local"
mkdir -p "$(dirname "$RC")"
if [ -f "$RC" ]; then
  cp "$RC" "$RC.edgelink.bak" 2>/dev/null || true
fi
cat > "$RC" <<'EOF'
# --- EdgeLink EL-953 force LAN + diag (injected) ---
DIAG=/tmp/el953-diag.log
{
  echo "=== boot diag $(date) ==="
  echo "--- ip link ---"; ip link 2>&1
  echo "--- eth0 ---"; ip link show eth0 2>&1
  echo "--- eth1 ---"; ip link show eth1 2>&1
  echo "--- switch0 (swconfig) ---"; swconfig dev switch0 show 2>&1 || echo "no switch0"
  echo "--- board_name ---"; cat /tmp/sysinfo/board_name 2>&1
  echo "--- model ---"; cat /tmp/sysinfo/model 2>&1
  echo "--- network cfg ---"; cat /etc/config/network 2>&1
} > "$DIAG" 2>&1
# also persist to overlay (r/w) if mounted
mountpoint -q /etc 2>/dev/null && cp "$DIAG" /etc/el953-diag.log 2>/dev/null
# Force eth0 up + give LAN a static addr even if network scripts did not run
ip link set eth0 up 2>&1
ip addr add 192.168.1.1/24 dev eth0 2>/dev/null || true
ip link set br-lan up 2>/dev/null || true
exit 0
EOF
chmod +x "$RC"
echo "rc.local injected; boot diag at /tmp/el953-diag.log (+overlay /etc/el953-diag.log if r/w)"

echo "device-add.sh done"
