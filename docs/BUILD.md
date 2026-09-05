# OpenWrt 25.12 构建指南

## 项目概述

本项目为 EdgeLink EL-953 4G CPE 提供基于 OpenWrt 25.12 的固件支持。

**硬件规格：**
- SoC: QCA9531 @ 650MHz
- RAM: 128MB DDR2
- Flash: 16MB SPI NOR
- 网口: 1x WAN + 1x LAN (FastEthernet)
- 无线: 2.4GHz 802.11n
- 4G: Quectel EC200T (USB ECM 模式)
- LED: 4颗状态指示灯（LAN/4G/SIM/WiFi）
- 按钮: 1个 Reset 按钮

## GitHub Actions 自动构建

### 触发构建

推送到 `main` 分支或手动触发 workflow：

```bash
git push origin main
```

或在 GitHub 仓库页面：
**Actions → Build OpenWrt Firmware → Run workflow**

### 构建流程

1. **拉取源码**: 从 OpenWrt 官方仓库拉取 openwrt-25.12 分支
2. **应用补丁**: 运行 `patches/device-add.sh` 添加设备支持
3. **更新 feeds**: 安装所有软件包源
4. **配置**: 生成设备专用配置
5. **编译**: 多核并行编译（约 2-3 小时）
6. **上传**: 固件作为 artifact 保存

### 下载固件

构建完成后，在 **Actions** 页面找到对应的 workflow run，下载：
- `openwrt-firmware-edgelink_el-953`: 包含 sysupgrade.bin 和 factory.bin
- `build-config`: 完整的 .config 文件

## 本地构建（可选）

如果需要在本地编译（需要 Linux 环境）：

```bash
# 1. 克隆本项目
git clone https://github.com/r3zound/OpenWRT-25.12-QCA953X.git
cd OpenWRT-25.12-QCA953X

# 2. 拉取 OpenWrt 源码
git clone --depth 1 --branch openwrt-25.12 \
  https://github.com/openwrt/openwrt.git openwrt-src

# 3. 应用设备补丁
cd openwrt-src
bash ../patches/device-add.sh .

# 4. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 配置（使用预设配置或自定义）
make menuconfig
# Target System: Qualcomm Atheros AR7xxx/AR9xxx
# Subtarget: Generic devices with NAND flash
# Target Profile: EdgeLink EL-953

# 6. 下载依赖
make download -j$(nproc)

# 7. 编译
make -j$(nproc) V=s

# 8. 固件输出
ls -lh bin/targets/ath79/generic/*edgelink*
```

## 固件功能

### 预装软件包

**核心功能：**
- LuCI Web 管理界面（HTTPS）
- 防火墙管理
- USB 支持（kmod-usb2）

**4G/LTE 支持：**
- USB ECM 驱动（cdc-ether）
- USB 串口驱动（option, wwan）
- QMI 工具（uqmi）
- 3G 拨号支持（comgt）

**网络工具：**
- wget-ssl
- curl
- htop
- iperf3

### 4G 模块配置

EC200T 模块工作在 **ECM 模式**（USB VID:PID = 2c7c:6026）：

1. 模块上电后自动创建 `usb0` 网络接口
2. 系统自动配置为 WAN 口（DHCP 模式）
3. 模块提供 NAT 功能（192.168.43.x 网段）
4. 无需 QMI/PPP 拨号，插卡即用

**LuCI 配置路径：**
- 网络 → 接口 → WAN（默认已配置为 usb0）
- 系统 → LED 配置（可绑定 4G 状态 LED）

## 刷机方法

### 首次刷机（Breed 引导）

设备出厂使用 Breed Bootloader：

1. 断电，按住 Reset 按钮
2. 上电，保持按住 5 秒后松开
3. 浏览器访问 `192.168.1.1`
4. **固件更新 → 勾选"自动重启" → 上传 factory.bin**
5. 等待刷写完成自动重启

### 升级固件（已刷 OpenWrt）

LuCI 界面升级：
1. **系统 → 备份/升级**
2. **刷写新的固件 → 上传 sysupgrade.bin**
3. **取消勾选"保留配置"（首次升级推荐）**
4. 点击**继续**开始升级

命令行升级：
```bash
scp openwrt-*-sysupgrade.bin root@192.168.1.1:/tmp/
ssh root@192.168.1.1
sysupgrade -v /tmp/openwrt-*-sysupgrade.bin
```

## 首次启动配置

1. **连接设备：**
   - 网线接入 LAN 口
   - 电脑设置为自动获取 IP（192.168.1.x）

2. **访问 LuCI：**
   - 浏览器打开 `http://192.168.1.1`
   - 默认无密码，首次登录需设置 root 密码

3. **配置 WiFi：**
   - **网络 → 无线**
   - 启用 2.4GHz 无线，设置 SSID 和密码

4. **插入 SIM 卡：**
   - 断电插卡（联通/电信 4G 卡）
   - 上电后等待 30 秒，4G LED 应该常亮
   - **网络 → 接口** 确认 WAN 获取到 IP

5. **测试连接：**
   - **网络 → 诊断** 执行 Ping 测试

## 故障排除

### 4G 模块不识别

```bash
# SSH 登录设备
ssh root@192.168.1.1

# 检查 USB 设备
lsusb
# 应看到: ID 2c7c:6026 Quectel Wireless Solutions Co., Ltd.

# 检查网络接口
ifconfig usb0
# 应看到: inet addr:192.168.43.x

# 检查路由
route -n
# 应看到: 0.0.0.0 via 192.168.43.1 dev usb0
```

### 编译失败排查

1. **磁盘空间不足**
   - GitHub Actions: workflow 已包含清理步骤
   - 本地编译: 确保至少 30GB 可用空间

2. **网络下载超时**
   - 使用国内镜像（配置 `~/.gitconfig` 和 `~/.bashrc`）
   - 或手动下载 `dl/` 目录内容

3. **依赖包缺失**
   - Ubuntu/Debian: `sudo apt-get install build-essential ...`
   - 参考 OpenWrt 官方文档

## 开发贡献

欢迎提交 Issue 和 Pull Request！

**常见改进方向：**
- 添加更多 4G 模块支持（如 EC20、EC25）
- 优化 LED 状态脚本
- 集成更多实用软件包
- 支持其他 QCA953X 设备

## 许可证

本项目基于 GPL-2.0 许可证发布，与 OpenWrt 保持一致。

## 相关链接

- [OpenWrt 官方网站](https://openwrt.org/)
- [OpenWrt 源码仓库](https://github.com/openwrt/openwrt)
- [QCA953X 芯片手册](https://www.qualcomm.cn/)
- [Quectel EC200T 资料](https://www.quectel.com/product/lte-ec200t-cn/)
