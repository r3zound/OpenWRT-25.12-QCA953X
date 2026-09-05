# OpenWRT 25.12 for QCA953X

OpenWrt 固件项目，针对 QCA953X 系列芯片。

## 硬件平台

- SoC: QCA9531
- Flash: 16MB
- RAM: 128MB
- 网络: 1×WAN + 1×LAN
- 无线: 2.4GHz
- 4G: Quectel EC200T (ECM mode)

## 构建环境

基于 OpenWrt/ImmortalWrt 25.12 分支。

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/r3zound/OpenWRT-25.12-QCA953X.git
cd OpenWRT-25.12-QCA953X

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 配置
make menuconfig

# 编译
make -j$(nproc) V=s
```

## 项目结构

```
.
├── README.md           # 项目说明
├── .gitignore         # Git 忽略规则
├── files/             # 自定义文件（会被打包到固件）
├── patches/           # 补丁文件
└── configs/           # 设备配置文件
```

## 开发说明

### 4G 模块配置

EC200T 模块默认 ECM 模式 (VID:PID = 2c7c:6026)：
- 驱动: `kmod-usb-net-cdc-ether`
- 网络接口: `usb0`
- 协议: `static` (192.168.43.100/24, gateway 192.168.43.1)
- DNS: 223.5.5.5, 119.29.29.29

### 构建注意事项

- 确保包含 `cdc_ether` 驱动
- Firewall 需配置 masquerade
- 建议使用 static IP 而非 dhcp (模块 DHCP 不稳定)

## License

遵循 OpenWrt 项目许可证 (GPL-2.0)
