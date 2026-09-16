#
# kmod-fwx —— 官方源码 Makefile 的修补版
#
# 原版问题：fwx 是无 PKG_SOURCE 的本地包，OpenWrt 25.12 的默认 Build/Prepare
# 只在 PKG_UNPACK 非空时才拷贝 ./src（include/package-defaults.mk 的
# ifneq ($(strip $(PKG_UNPACK)),) 分支），导致 PKG_BUILD_DIR 为空、
# fwx.ko 静默不产出、模块不进固件 —— 仪表盘/上网审计全无数据。
#
# 修补：1) 显式 Build/Prepare 拷贝 src  2) AUTOLOAD 移入 KernelPackage（开机自加载）
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=fwx
include $(INCLUDE_DIR)/package.mk

RSTRIP:=:

define KernelPackage/fwx
  SUBMENU:=Netfilter Extensions
  TITLE:=fwx netfilter module
  FILES:=$(PKG_BUILD_DIR)/fwx.ko
  DEPENDS:=+kmod-ipt-conntrack
  KCONFIG:=
  AUTOLOAD:=$(call AutoLoad,99,fwx)
endef

define KernelPackage/fwx/description
  fwx netfilter module
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/. $(PKG_BUILD_DIR)/
endef

KCFLAGS := -Wno-error=missing-prototypes \
           -Wno-error=missing-declarations \
           -Wno-error=unused-variable \
           -Wno-error=declaration-after-statement \
           -Wno-error=implicit-fallthrough \
           -Wno-error=missing-braces \
           -Wno-error=parentheses \
           -Wno-error=format \
           -Wno-frame-larger-than

MAKE_OPTS:= \
	$(KERNEL_MAKE_FLAGS) \
	M="$(PKG_BUILD_DIR)" \
	KCFLAGS="$(KCFLAGS)" \
	$(EXTRA_KCONFIG)

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(MAKE_OPTS) \
		modules
endef

$(eval $(call KernelPackage,fwx))
