# FanchmWrt for 京东云无线宝亚瑟一代 (RE-SP-01B / MT7621)

这是为 **京东云无线宝亚瑟一代 (RE-SP-01B, MT7621AT)** 定制的 FanchmWrt 固件，基于官方源码 [fanchmwrt/fanchmwrt](https://github.com/fanchmwrt/fanchmwrt) 分支 `fanchmwrt-25.12.4` 构建。

FanchmWrt 是 OpenAppFilter 作者 destan19 主导的开源固件，默认提供上网审计、应用过滤、行为管理、系统监控等家庭网关功能。本仓库在官方基础上做了亚瑟一代设备的适配、精简和常用工具补充，并通过 GitHub Actions 自动编译发布。

---

## 适用设备

| 项目 | 说明 |
|------|------|
| 设备 | 京东云无线宝亚瑟一代 (RE-SP-01B) |
| SoC | MediaTek MT7621AT (MIPS 1004Kc) |
| RAM | 256 MB |
| Flash | 16 MB |
| 平台 | ramips / mt7621 |
| 目标文件名 | `openwrt-ramips-mt7621-jdcloud_re-sp-01b-squashfs-sysupgrade.bin` |

> 文件名前缀仍为 `openwrt-*` 是因为目前基于官方 FanchmWrt 源码构建；固件运行后 Web 后台显示为 FanchmWrt。

---

## 最新 Release

- **下载地址**：https://github.com/pcy0124m/FanchmWrt/releases/latest
- **当前最新 tag**：`v202609162136`
- **构建状态**：✅ 成功
- **固件大小**：约 14.6 MB（sysupgrade）

| 文件 | 说明 |
|------|------|
| `openwrt-ramips-mt7621-jdcloud_re-sp-01b-squashfs-sysupgrade.bin` | 正常刷机用，通过 LuCI 或 breed 烧录 |
| `openwrt-ramips-mt7621-jdcloud_re-sp-01b-initramfs-kernel.bin` | initramfs 版本，临时启动或救砖用 |

---

## 默认配置

| 配置项 | 默认值 |
|--------|--------|
| LAN IP | `192.168.12.1` |
| root 密码 | 空（首次登录不填密码） |
| Web 后台 | http://192.168.12.1 |
| 2.4G SSID | `FanchmWrt-2.4G` |
| 5G SSID | `FanchmWrt-5G` |
| WiFi 密码 | `fanchm12345` |
| 默认主题 | FanchmWrt 官方主题 |

> 首次进入 Web 后建议先修改 root 密码。

---

## 主要特性

本固件在官方 FanchmWrt 基础上做了以下定制：

- **FanchmWrt 官方应用全家桶**：dashboard、应用过滤、上网审计、行为管理、系统监控、家长控制、域名过滤、广告屏蔽、App Center 等 17 个 `luci-app-fwx-*` 插件。
- **修复 kmod-fwx 数据采集问题**：官方源码的 `kmod-fwx` 在 OpenWrt 25.12 下因 `Build/Prepare` 缺失导致 `fwx.ko` 未产出；本仓库通过补丁显式定义构建步骤并加 CI 硬校验，确保数据采集模块正常进固件。
- **一键 extroot 脚本**：固件内置 `/root/extroot-setup.sh`，可将 `/overlay` 迁移到 USB 移动硬盘，解决 16 MB Flash 容量不足问题，同时把剩余空间挂为 `/mnt/data` 数据盘。
- **精简但够用**：移除 `ttyd`、`samba4`、`bash`、`htop`、`iperf3`、`tcpdump` 等占空间组件；保留文件管理器、软件包管理器、`block-mount`、`ext4`、`fdisk`、`e2fsprogs`，方便挂盘和扩展。
- **Web 界面支持高级模式**：部分原生 LuCI 功能（文件管理器等）需要切换到「高级模式」才可见。

---

## 刷机说明

###  prerequisites

- 亚瑟一代需要先刷入 **breed** 引导（SOP16 夹刷，网上教程很多）。
- 准备网线连接 LAN 口。

### 刷机步骤

1. 从 [Releases](https://github.com/pcy0124m/FanchmWrt/releases/latest) 下载 `squashfs-sysupgrade.bin`。
2. 进入 breed：断电 → 按住 reset → 插电 → 等待 5 秒后松开，电脑访问 `192.168.1.1`。
3. 在 breed 中刷入固件，或启动后通过 FanchmWrt 的 LuCI 后台「系统 → 备份/升级」上传固件。
4. **升级时务必勾选「不保留配置」**，尤其是跨版本或之前做过 extroot 的情况下。
5. 重启后访问 `192.168.12.1`，按默认密码进入。

### 验证关键功能

刷机后建议跑两条命令确认核心模块已加载：

```sh
lsmod | grep fwx
# 有 fwx 输出才说明数据采集/上网审计模块正常。

# 查看 extroot 是否已启用
mount | grep overlay
```

---

## 一键扩展 overlay（extroot）

亚瑟一代 Flash 只有 16 MB，装几个插件就满了。推荐把 overlay 迁到 USB 移动硬盘。

### 前置要求

- 一个移动硬盘（机械/固态均可）。
- 刷的是本仓库最新 Release。

### 使用步骤

1. 把移动硬盘插到路由器 USB 口。
2. SSH 登录路由器：
   ```sh
   ssh root@192.168.12.1
   ```
3. 执行内置脚本：
   ```sh
   sh /root/extroot-setup.sh /dev/sda 8
   ```
   - `/dev/sda`：你的硬盘设备名（脚本也支持无参数交互式选择）。
   - `8`：给 overlay 分配 8 GB，剩余全部给 `/mnt/data` 数据盘。
4. 脚本会让你输入大写 `YES` 确认，确认后自动分区、格式化、迁移并写入 fstab。
5. 重启后验证：
   ```sh
   df -h /                # 根目录应显示约 8 GB
   mount | grep overlay   # 应看到 /dev/sda1 on /overlay
   ls /mnt/data           # 数据盘已挂载
   ```

### 重要提醒

- **会清空整盘数据**。
- **做完 extroot 后，硬盘就是系统盘，不要拔**。要拔盘必须先恢复内置 overlay 或重刷固件。
- 再次刷机时务必选择「不保留配置」，否则旧 overlay 数据可能覆盖新系统导致界面 404。

---

## 项目结构

```text
.
├── .github/workflows/build-fanchmwrt.yml   # GitHub Actions 编译工作流
├── configs/
│   └── fanchmwrt-ramips-mt7621.seed          # 固件配置种子
├── files/
│   ├── etc/uci-defaults/99-fanchmwrt         # 默认 IP、密码、WiFi 等初始化
│   └── root/extroot-setup.sh                 # 一键 extroot 脚本
├── overlays/package/fcm/fwx/Makefile         # kmod-fwx 构建补丁
└── README.md                                 # 本文件
```

---

## 自行构建

如果你想自己改配置后重新编译：

1. Fork 本仓库。
2. 修改 `configs/fanchmwrt-ramips-mt7621.seed`。
3. 推送后 GitHub Actions 会自动开始编译。
4. 编译成功后自动发布到 Releases。

构建大约需要 60–90 分钟。Actions 工作流已包含关键校验：

- `defconfig` 后检查关键包未被静默丢弃；
- 编译完成后硬校验 `fwx.ko` 是否真实存在于根文件系统中。

---

## 已知问题与限制

| 问题 | 说明 |
|------|------|
| 文件名前缀为 `openwrt-*` | 不影响使用，官方源码构建产物目前仍保留此前缀 |
| TF/SD 卡槽空载时可能刷屏 | 未插卡时 MMC 控制器轮询报错，无害；插卡可消除 |
| extroot 后拔盘无法启动 | 这是 extroot 本身的特性，不是 bug；硬盘需长期插在路由器上 |
| 部分功能需「高级模式」 | 文件管理器等原生 LuCI 功能在 FanchmWrt 高级模式下才可见 |

---

## 致谢

- [FanchmWrt 官方](https://github.com/fanchmwrt/fanchmwrt) 及 OpenAppFilter 作者 destan19
- [OpenWrt](https://github.com/openwrt/openwrt) 项目
- 京东云无线宝亚瑟一代的 breed/uboot 社区资料

---

> 本仓库为个人学习与设备适配用途，不提供任何商业担保。刷机有风险，请确保已了解 breed 救砖流程后再操作。
