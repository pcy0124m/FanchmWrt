# FanchmWrt

官方 FanchmWrt 固件自编译 · 京东云无线宝一代（亚瑟 **RE-SP-01B**，MT7621AT）

基于官方 FanchmWrt 源码（`github.com/fanchmwrt/fanchmwrt`，分支 `fanchmwrt-25.12.4`）
GitHub Actions 云端编译，产物自动发 Release。

> 官方下载站（download.ttcoder.cn）暂未发布 RE-SP-01B 的固件（其「亚瑟」为二代 RE-SS-01），
> 本仓库按官方源码为 RE-SP-01B 编译，界面与官方一致（仪表板 / 终端列表 / 行为管理 /
> 上网审计 / 高级设置）。

## 仓库结构

| 路径 | 作用 |
|---|---|
| `.github/workflows/build-fanchmwrt.yml` | 云端编译流水线 |
| `configs/fanchmwrt-ramips-mt7621.seed` | 固件功能配置（要加删软件包改这里） |
| `files/etc/banner` | 登录后显示的品牌横幅 |
| `files/etc/uci-defaults/99-fanchmwrt` | 首次启动定制（主机名、SSID、时区） |

## 使用步骤

1. **推到你的 GitHub 仓库**（本地执行）：

   ```bash
   cd fanchmwrt
   git init && git add . && git commit -m "FanchmWrt init"
   gh repo create FanchmWrt --public --source=. --push
   ```

2. **触发编译**：仓库页 → Actions → `Build FanchmWrt` → `Run workflow`。
   全量编译约 2~3 小时，跑完在 Artifacts 下载 `FanchmWrt-*.zip`。

3. **打 tag 自动发 Release**（可选）：

   ```bash
   git tag v1.0 && git push origin v1.0
   ```

## 内置功能与入口

| 功能 | 入口 |
|---|---|
| 仪表板 / 终端列表 / 行为管理 / 上网审计 | 默认「普通模式」左侧菜单 |
| **文件管理器** | 右上角切「**高级模式**」→ 系统 → File Manager（上传/下载/编辑/改权限/HEX） |
| **应用（软件包）管理** | 高级模式 → 系统 → 软件包（apk） |
| 网页终端 | 高级模式 → 系统 → TTYD Terminal |
| 应用中心 | FanchmWrt 自带（依赖官方在线源，MT7621 上可能为空） |

## 产物说明

| 文件 | 用途 |
|---|---|
| `*-initramfs-kernel.bin` | 临时启动测试用（不写入 flash，重启即失） |
| `*-squashfs-sysupgrade.bin` | 正式固件（从 OpenWrt/breed 内升级用） |

## ⚠️ 刷机前必读（重要）

- **官方 bootloader 不认第三方固件**。官方固件的 web 恢复界面（按住 reset 上电，电脑设
  `192.168.68.2`，访问 `http://192.168.68.1`）只收官方签名镜像。
- 因此刷 FanchmWrt **必须先换第三方 bootloader（breed 不死引导）**，需要 **SOP16 编程器夹**
  把 breed 烧写到 SPI NOR flash。这是硬性前提，没有夹子就得拆机接线或找有设备的人。
- 烧好 breed 后：进入 breed（`192.168.1.1`）→ 固件更新 → 选 `*-squashfs-sysupgrade.bin` 刷入。
- 变砖风险自担：breed 是不死引导，就算固件刷坏也能重进 breed 重刷，但 breed 本身烧写失误会砖。

## 常见修改

- **加/删软件包**：改 `configs/fanchmwrt-ramips-mt7621.seed` 里的 `CONFIG_PACKAGE_xxx=y`，push 自动触发重编译。
- **换 OpenWrt 版本**：改 workflow 里的 `REPO_BRANCH`（如 `master`）。
- **加第三方插件 feed**（如 kenzok8 的 luci 插件合集）：在 workflow 的克隆步骤后加：

  ```bash
  echo 'src-git ken https://github.com/kenzok8/openwrt-packages' >> feeds.conf.default
  ./scripts/feeds update -a && ./scripts/feeds install -a
  ```

  注意：workflow 里已在克隆后自动跑 `feeds update -a && feeds install -a`，直接加 `src-git` 行即可。
