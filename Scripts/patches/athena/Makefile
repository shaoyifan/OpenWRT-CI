# luci-app-athena-led - Standardized LuCI.mk version
# 用于覆盖 xiaren2/JDC-AX6600-Athena-LED-Controller js 分支的手写 Makefile
#
# 优势：
# 1. 自动 install root/ 下所有文件（包括 /usr/share/rpcd/acl.d/*.json）→ ACL bug 自愈
# 2. 自动 install htdocs/ 到 /www/
# 3. 自动 install po/<lang>/*.po → 编译成 .lmo + 生成 luci-i18n-xxx 子包
# 4. 不再需要 Handles.sh 第 13 段的 ACL sed 注入
# 5. luci-i18n-athena-led-zh-cn 子包自动生成 → Handles.sh 第 12 段的 i18n sed 删除也可清理
#
# athena-led 二进制的 install 方式：
# luci.mk 默认 Build/Prepare 会：cp source dirs 到 PKG_BUILD_DIR + 调用我们的钩子 + 解压 PKG_SOURCE
# 在 line 207 的 `$(call Build/Prepare/$(LUCI_NAME))` 钩子里把解压出来的 athena-led 二进制
# 拷到 PKG_BUILD_DIR/root/usr/bin/，luci.mk 默认 Package/install 段会通过 cp root/* 一并 install 到镜像。
# 不 override 任何 luci.mk 默认段，最小侵入。

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-athena-led
PKG_VERSION:=1.0.5
PKG_RELEASE:=1

PKG_MAINTAINER:=unraveloop <https://github.com/unraveloop>
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

# athena-led Rust 二进制（aarch64 musl 静态链接）从 GitHub Releases 下载
PKG_SOURCE:=athena-led-aarch64-unknown-linux-musl-v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/xiaren2/JDC-AX6600-Athena-LED-Controller/releases/download/v$(PKG_VERSION)/
PKG_HASH:=skip

# luci.mk 标准接口（自动 install root/ htdocs/ luasrc/ po/，自动生成 luci-i18n-* 子包）
LUCI_TITLE:=LuCI Support for Athena LED (Enhanced)
LUCI_DESCRIPTION:=Enhanced LuCI support for JDCloud AX6600 (Athena) LED Screen Control.
LUCI_DEPENDS:=+luci-base @(aarch64||arm)
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# luci.mk 的 Build/Prepare 段在 line 207 调用 `$(call Build/Prepare/$(LUCI_NAME))`，
# 这里利用这个钩子点把解压到 PKG_BUILD_DIR 的 athena-led 二进制塞到 root/usr/bin/，
# 这样 luci.mk 默认 Package/install 段 `cp -pR $(PKG_BUILD_DIR)/root/* $(1)/` 会一并 install 到镜像。
# 调用时序：luci.mk Build/Prepare 流程为
#   1) cp source dirs (luasrc/ucode/htdocs/root/src) → PKG_BUILD_DIR
#   2) 调用 Build/Prepare/luci-app-athena-led（本钩子）— PKG_BUILD_DIR/root/ 已存在，INSTLL_DIR 安全
#   3) 解压 PKG_SOURCE → PKG_BUILD_DIR（含 athena-led 二进制）
# 所以我们在钩子里 INSTALL_BIN 的目标是 PKG_BUILD_DIR/athena-led，由步骤 3 解压得到。
define Build/Prepare/luci-app-athena-led
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/root/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/athena-led $(PKG_BUILD_DIR)/root/usr/bin/athena-led
endef