# OpenWRT 25.12 for QCA953X

OpenWrt 25.12 overlay project for QCA953X-based boards, currently targeting the
**EdgeLink EL-953** (the bare-board industrial 4G router documented in
`docs/edgelink_el-953.md`).

## 硬件平台 (EdgeLink EL-953)

- SoC: QCA9531
- Flash: 16 MB SPI NOR
- RAM: 128 MB DDR2
- Network: 1×WAN (eth1) + 1×LAN (eth0, AR8229 switch)
- WiFi: 2.4 GHz b/g/n (ath9k-phy0)
- 4G: Quectel EC200T (CDC-ECM mode, VID:PID `2c7c:6026`)
- Bootloader: Breed

See [docs/edgelink_el-953.md](docs/edgelink_el-953.md) for full hardware reference
(GPIOs, MAC addresses, flash layout, LEDs).

## 构建环境

Based on the OpenWrt 25.12 branch (kernel 6.12). Overlay structure — source
trees are **not** vendored into this repo; pull them in via `feeds`.

## 快速开始

```bash
# 1. clone main source alongside this overlay (sibling directory)
git clone https://github.com/Y0518/immortalwrt.git -b openwrt-25.12
git clone https://github.com/r3zound/OpenWRT-25.12-QCA953X.git
cd immortalwrt

# 2. apply device overlay (DTS + 01_leds + 02_network + 99-edgelink-4g)
bash ../OpenWRT-25.12-QCA953X/patches/device-add.sh .

# 3. set up feeds (see feeds.conf.example in the overlay repo)
cp ../OpenWRT-25.12-QCA953X/feeds.conf.example feeds.conf
./scripts/feeds update -a
./scripts/feeds install -a

# 4. apply the proven package set
cat ../OpenWRT-25.12-QCA953X/configs/edgelink_el-953.config >> .config
make defconfig

# 5. build
make -j$(nproc) V=s
```

## 项目结构

```
.
├── README.md                       # 本文件
├── .gitignore                      # Git 忽略规则
├── docs/
│   └── edgelink_el-953.md          # 硬件参考 (DTS/MAC/GPIO/LED/Flash)
├── files/                          # 自定义文件（会被打包到固件）
├── patches/                        # 设备补丁
│   ├── qca9531_edgelink_el-953.dts # 25.12 DTS（nvmem-layout 格式）
│   └── device-add.sh               # 把 DTS / leds / network / 4G-WAN 注入上游源码
├── configs/
│   └── edgelink_el-953.config      # defconfig 片段（modeminfo/atinout/cdc_ether…）
└── feeds.conf.example              # feeds 配置示范（含 modemfeed commit pin）
```

## 开发说明

### 4G 模块配置

EC200T 模块默认 ECM 模式 (VID:PID = `2c7c:6026`)：
- 驱动: `kmod-usb-net-cdc-ether`
- 网络接口: `usb0`
- 协议: `static`（`192.168.43.100/24`，gateway `192.168.43.1`，metric `10`）
- DNS: `223.5.5.5`, `119.29.29.29`（静态——ECM 模块不提供 DHCP DNS）
- Firewall: `masquerade` on wan
- **不要用 dhcp 模式**（`udhcpc` 常 no lease）

### 4G 供电

- GPIO **2** HIGH（`patches/device-add.sh` 注入的 `99-edgelink-4g` 启动脚本中拉高）
- 未拉高会导致 bootloop（参见 0020345）

### 构建注意事项

- 确保包含 `cdc_ether` 驱动（已在 defconfig 中）
- `kmod-usb-serial-option` + `kmod-usb-serial-qualcomm` + `kmod-usb-serial-wwan`
  必备，否则 AT 口不可用
- `modeminfo` / `atinout` / `luci-app-*` 配套安装方便调试

## 历史与来源

- `patches/qca9531_edgelink_el-953.dts`：从 ImmortalWrt 21.02 DTS 迁移到 25.12
  `nvmem-layout` 格式（`d1e1880`）。
- `patches/device-add.sh`：上游源码注入脚本，包含
  - DTS 拷贝
  - 01_leds / 02_network case 注入
  - `99-edgelink-4g` uci-defaults（默认 wan 走 4G）
  - `rc.local` net-debug 注入（强制 eth0/LAN 起来 + 启动日志）
- `configs/edgelink_el-953.config`：从 `r3zound/immortalwrt-ath79` 21.02
  已验证 `.config` 迁移过来的软件包选择。
- `docs/edgelink_el-953.md`：硬件参考表，与 `r3zound/immortalwrt-ath79` README
  对齐。

## License

遵循 OpenWrt 项目许可证 (GPL-2.0)
