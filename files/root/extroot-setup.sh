#!/bin/sh
# ============================================================
# FanchmWrt 一键 extroot 脚本
# 把 overlay 迁移到 USB 移动硬盘，同时把剩余空间挂成数据盘
#
# 用法:  sh /root/extroot-setup.sh [设备] [overlay分区大小(GB)]
# 例:    sh /root/extroot-setup.sh /dev/sda 8
#        不带参数则交互式选择
#
# 结果:  sda1 -> /overlay (系统盘, 默认 8G)
#        sda2 -> /mnt/data (数据盘, 剩余全部)
#
# ⚠ 会清空目标磁盘上的所有数据
# ⚠ 做完后移动硬盘就是系统盘，不能拔；拔了开机进不了系统
# ============================================================

DEV="${1:-}"
OVL_SIZE="${2:-8}"
OVL_LABEL="overlay"
DATA_LABEL="data"

log()  { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[-]\033[0m %s\n' "$*"; exit 1; }

# ---------------- 0. 前置检查 ----------------
[ "$(id -u)" = "0" ] || err "必须用 root 运行"

# 已经做过 extroot（挂在外置盘上）就别再跑；mtdblock 是内置 flash，属正常
OVL_DEV=$(awk '$2=="/overlay"{print $1}' /proc/mounts 2>/dev/null)
case "$OVL_DEV" in
  /dev/sd*|/dev/mmcblk*|/dev/nvme*|/dev/vd*|/dev/hd*) \
    err "检测到 /overlay 已挂在外置盘 $OVL_DEV 上，无需重复执行" ;;
esac

for t in fdisk mkfs.ext4 block blkid tar uci; do
  command -v "$t" >/dev/null 2>&1 || \
    err "缺少命令: $t  —— 该固件未内置 block-mount / e2fsprogs / fdisk，请换用完整版固件"
done

# ---------------- 1. 选磁盘 ----------------
if [ -z "$DEV" ]; then
  log "检测到的磁盘："
  for d in /dev/sd? /dev/mmcblk? /dev/vd?; do
    [ -e "$d" ] || continue
    printf '  %s\n' "$d"
    block info "$d" 2>/dev/null | sed 's/^/      /'
  done
  printf '请输入要使用的磁盘 (如 /dev/sda): '
  read DEV
fi
[ -e "$DEV" ] || err "设备 $DEV 不存在"

# 分区命名规则：mmcblk 要加 p
case "$DEV" in
  *mmcblk*|*nvme*) P1="${DEV}p1"; P2="${DEV}p2" ;;
  *)               P1="${DEV}1";  P2="${DEV}2"  ;;
esac

# ---------------- 2. 卸载已挂载的分区 ----------------
for p in "${P1}" "${P2}" "${DEV}"?*; do
  [ -e "$p" ] || continue
  m=$(awk -v d="$p" '$1==d{print $2}' /proc/mounts 2>/dev/null)
  if [ -n "$m" ]; then
    warn "卸载 $p (挂载于 $m)"
    umount -f "$p" 2>/dev/null
  fi
done
swapoff "${DEV}"?* 2>/dev/null

# ---------------- 3. 二次确认 ----------------
warn "=========================================================="
warn "  目标磁盘 : $DEV"
warn "  分区方案 : $P1 = ${OVL_SIZE}G  -> /overlay (系统盘)"
warn "             $P2 = 剩余全部 -> /mnt/data (数据盘)"
warn "  !! 该磁盘上的所有数据将被清空，不可恢复 !!"
warn "=========================================================="
printf '确认请输入大写 YES: '
read ANS
[ "$ANS" = "YES" ] || err "已取消，未做任何改动"

# ---------------- 4. 分区 ----------------
log "写入分区表并创建分区 ..."
fdisk "$DEV" >/dev/null 2>&1 <<EOF
o
n
p
1

+${OVL_SIZE}G
n
p
2


w
EOF
sync
sleep 3
[ -e "$P1" ] || err "分区 $P1 未生成，请检查磁盘状态（fdisk -l $DEV）"
[ -e "$P2" ] || err "分区 $P2 未生成，请检查磁盘状态（fdisk -l $DEV）"

# ---------------- 5. 格式化 ----------------
log "格式化 $P1 为 ext4 (overlay) ..."
mkfs.ext4 -F -L "$OVL_LABEL" "$P1" >/dev/null 2>&1 || err "格式化 $P1 失败"
log "格式化 $P2 为 ext4 (data) ..."
mkfs.ext4 -F -L "$DATA_LABEL" "$P2" >/dev/null 2>&1 || err "格式化 $P2 失败"
sync
sleep 1

# ---------------- 6. 复制 overlay ----------------
mkdir -p /mnt/extroot
mount "$P1" /mnt/extroot || err "挂载 $P1 失败"
log "复制当前 /overlay 内容到 $P1 ..."
tar -C /overlay -cf - . 2>/dev/null | tar -C /mnt/extroot -xf - 2>/dev/null
sync
umount /mnt/extroot || err "卸载 $P1 失败"
rmdir /mnt/extroot 2>/dev/null

# ---------------- 7. 写 fstab ----------------
log "写入 /etc/config/fstab ..."
UUID1=$(blkid -s UUID -o value "$P1" 2>/dev/null)
UUID2=$(blkid -s UUID -o value "$P2" 2>/dev/null)
[ -n "$UUID1" ] || err "无法获取 $P1 的 UUID"
[ -n "$UUID2" ] || err "无法获取 $P2 的 UUID"

# 清掉旧的 mount 段，避免和 block detect 生成的重复
while uci -q delete fstab.@mount[0] >/dev/null 2>&1; do :; done

uci set fstab.overlay=mount
uci set fstab.overlay.uuid="$UUID1"
uci set fstab.overlay.target='/overlay'
uci set fstab.overlay.fstype='ext4'
uci set fstab.overlay.options='rw,noatime'
uci set fstab.overlay.enabled='1'
uci set fstab.overlay.check_fs='1'
uci set fstab.overlay.enabled_fsck='0'

uci set fstab.data=mount
uci set fstab.data.uuid="$UUID2"
uci set fstab.data.target='/mnt/data'
uci set fstab.data.fstype='ext4'
uci set fstab.data.options='rw,noatime'
uci set fstab.data.enabled='1'
uci set fstab.data.check_fs='0'
uci set fstab.data.enabled_fsck='0'

uci set fstab.global=global
uci set fstab.global.anon_swap='0'
uci set fstab.global.anon_mount='1'
uci set fstab.global.auto_swap='0'
uci set fstab.global.auto_mount='1'
uci set fstab.global.check_fs='0'
uci set fstab.global.delay_root='15'
uci commit fstab

mkdir -p /mnt/data
sync

# ---------------- 8. 完成 ----------------
log "=========================================================="
log " extroot 配置完成！"
log "=========================================================="
echo ""
echo " 重启后验证："
echo "   df -h /                 -> 根目录应约 ${OVL_SIZE}G"
echo "   mount | grep overlay    -> 应显示 $P1 on /overlay"
echo "   ls /mnt/data            -> 数据盘（下载/Samba 共享目录）"
echo ""
echo " 救急办法：拔掉移动硬盘开机 -> 回落到内部 flash 启动"
echo "            -> LuCI 上传之前 sysupgrade -b 的备份恢复"
echo ""
printf '现在重启？(y/N): '
read R
case "$R" in
  y|Y) log "重启中 ..."; reboot ;;
  *)   log "已跳过重启，记得手动 reboot" ;;
esac
