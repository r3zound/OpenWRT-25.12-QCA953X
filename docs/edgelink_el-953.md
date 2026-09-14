# EdgeLink EL-953 — Hardware Reference

Single-board industrial 4G router, bare PCB (no brand-marketed equivalent).
Profile name in OpenWrt: `edgelink,el-953`.

## Hardware

| Category | Item | Value |
|---|---|---|
| Form | Device type | Industrial 4G module (not a consumer router) |
| SoC | Chip / kernel name | QCA9531 (kernel reports QCA9533) |
| Memory | Flash / RAM | 16 MB SPI NOR / 128 MB DDR2 |
| Network | Wired | 1 WAN (eth1, MII + phy4) + 1 LAN (eth0, GMII + AR8229 switch) |
| Cellular | 4G module / USB ID | Quectel EC200T (CN firmware) — USB `2c7c:6026` (CDC-ECM) |
| SIM | Slot | 1× standard SIM (inserted = LED off / ejected = LED blink) |
| Expansion | USB / TF / miniPCIe | **None** (not wired on PCB) |
| Wireless | WiFi | 2.4 GHz b/g/n (ath9k-phy0) |
| Boot | Bootloader | Breed (full.bin programmer backup saved) |
| Flash layout | u-boot / firmware / art | `0x000000` (128 K) / `0x020000` (tplink LZMA) / `0xff0000` (64 K) |
| MAC | art 0x0 | WAN `c8:ee:a6:bb:cc:23` / LAN `:24` / WiFi `c2:ee:a6:0c:38:07` |

## Reset button

- GPIO **17**, ACTIVE LOW, 60 ms debounce
- Linux code: `KEY_RESTART`

## LEDs (4 controllable, ACTIVE LOW)

| Color | Function | GPIO | DTS label |
|---|---|---|---|
| yellow | LAN link | 4 | `yellow:lan-link` |
| green | 4G status | 15 | `green:4g-status` |
| yellow | SIM status | 14 | `yellow:sim` |
| red | WiFi status | 12 | `red:wifi` |
| blue | power | — | hardware-driven, not controllable |

GPIO 11 and GPIO 16 are not connected on the PCB.

## 4G module specifics

- **Power**: GPIO **2** HIGH via `chkmodule` (startup; required to avoid bootloop)
- **Default mode**: CDC-ECM (PID `2c7c:6026`) — module does NAT internally
- **AT port**: `/dev/ttyUSB1`
- **Driver**: `cdc_ether` (no `qmi_wwan` / `ppp` needed)
- **WAN interface**: `usb0`, **static** `192.168.43.100/24`, gateway `192.168.43.1`, metric `10`
- **DNS** (static, ECM does not provide): `223.5.5.5`, `119.29.29.29`
- **Firewall**: masquerade on wan
- See AGENTS.md "4G 数据面'通'——根因纠正链" for the troubleshooting history.

## Provenance

- Originally documented against `r3zound/immortalwrt-ath79` (ImmortalWrt 21.02 self-contained build).
- Migrated to this 25.12 overlay (`r3zound/OpenWRT-25.12-QCA953X`) along with `defconfig` and feed examples.
