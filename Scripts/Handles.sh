#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改vantage进度条标签字体（anothaDev/luci-theme-vantage#52）
FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"




# 添加并配置 luci-app-athena-led
ATHENA_LED_DIR="../package/emortal/luci-app-athena-led"
REPO_URL="https://github.com/shaoyifan/athena-led.git"
TEMP_DIR="athena_led_temp"

# 彻底清理旧目录和临时目录
rm -rf "$ATHENA_LED_DIR" "$TEMP_DIR" 2>/dev/null

# 克隆到临时目录
if git clone -b main --depth=1 "$REPO_URL" "$TEMP_DIR"; then
    echo " "

    # 将子文件夹里的内容移动到目标位置
    # 假设子文件夹名也是 luci-app-athena-led
    mkdir -p "$ATHENA_LED_DIR"
    cp -r "$TEMP_DIR/luci-app-athena-led/"* "$ATHENA_LED_DIR/"
    rm -rf "$TEMP_DIR"

    MAKEFILE_PATH="$ATHENA_LED_DIR/Makefile"
    if [ -f "$MAKEFILE_PATH" ]; then
        # 移除特定的硬件依赖
        sed -i 's/@TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02//g' "$MAKEFILE_PATH"
        echo "@TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02 remove!"
    fi

    # 再次确认并设置执行权限
    # 注意：如果子文件夹里路径有变化，请检查这里
    [ -f "$ATHENA_LED_DIR/root/usr/sbin/athena-led" ] && chmod +x "$ATHENA_LED_DIR/root/usr/sbin/athena-led"
    [ -f "$ATHENA_LED_DIR/root/etc/init.d/athena_led" ] && chmod +x "$ATHENA_LED_DIR/root/etc/init.d/athena_led"

    echo "luci-app-athena-led has been added and fixed!"
fi



# --- 8. 添加 AdGuardHome 备份路径到 sysupgrade ---
SYS_CONF="../package/base-files/files/etc/sysupgrade.conf"
if [ -f "$SYS_CONF" ]; then
    echo " "
    cat > "$SYS_CONF" <<'EOF'
/etc/adguardhome/adguardhome.yaml
EOF
    echo "sysupgrade backup info has been updated!"
fi

#
## --- 9. 精简 qualcommax 平台 cpuusage 脚本的 NSS 输出 ---
## 原输出: NSS: load 7% freq 748.8MHz
## 期望输出: NSS: 7%
#CPU_USAGE="../target/linux/qualcommax/base-files/sbin/cpuusage"
#if [ -f "$CPU_USAGE" ]; then
#	echo " "
#
#	# 把 "NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}" 简化为 "NSS: ${nss_load:-N/A}"
#	sed -i 's|NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}|NSS: ${nss_load:-N/A}|g' $CPU_USAGE
#
#	cd $PKG_PATH && echo "cpuusage has been fixed!"
#fi
#
## --- 10. 把 LuCI 状态页的 CPU 使用率拆成两行（CPU / NSS ECM） ---
#SYS_10="../feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
#if [ -f "$SYS_10" ]; then
#	echo " "
#
#	# 步骤 1：在 var fields = [ 之前插入 4 行解析代码（cuMain / cuEcm）
#	sed -i "/var fields = \[/i\\
#	\\tvar cu = cpuusage.cpuusage || \"?\";\\
#	\\tvar m  = cu.match(/tcp\\\\s+\\\\d+.*total\\\\s+\\\\d+/);\\
#	\\tvar cuMain = m ? cu.replace(/\\\\s*tcp\\\\s+\\\\S+.*\$/, \"\") : cu;\\
#	\\tvar cuEcm  = m ? m[0] : null;\\
#
#	" "$SYS_10"
#
#	# 步骤 2：把 _('CPU usage (%)'), cpuusage.cpuusage 拆成两行（自动多渲染一行 ecm）。
#	# 加 /var cuMain/! 前缀做幂等：已打过补丁的文件里没有 cpuusage.cpuusage，匹配为空，sed 不会重写
#	sed -i "/var cuMain/!s#_('CPU usage (%)'),[[:space:]]*cpuusage\\.cpuusage#_('CPU usage (%)'),        cuMain,\\n\\t\\t\\t_('NSS连接数'),        cuEcm || '?',#" "$SYS_10"
#
#	cd $PKG_PATH && echo "10_system.js has been split!"
#fi

# --- 11. 预置 GeoSite.dat 到 nikki 后端包（编译后镜像自带，免去 mihomo 首次启动下载）---
# 源：Scripts/patches/nikki/GeoSite.dat（你自己放进去的文件，文件名大小写保留）
# 目标：nikki/files/run/GeoSite.dat → ipk install 时释放到镜像 /etc/nikki/run/GeoSite.dat
# 关键修正：GeoSite.dat 不是 luci-app-nikki（纯前端包）的事，是 nikki 后端包 + mihomo 内核的事
GEOSITE_SRC="$(dirname "$0")/patches/nikki/GeoSite.dat"
GEOSITE_NAME="$(basename "$GEOSITE_SRC")"
# 精确锁定 nikki 后端包：grep PKG_NAME:=nikki 排除 luci-app-nikki 干扰
NIKKI_PKG=$(find ../feeds/luci/applications ../feeds/packages ../package -maxdepth 6 -name "Makefile" 2>/dev/null | xargs grep -l "^PKG_NAME:=nikki$" 2>/dev/null | head -1 | xargs dirname)

if [ -f "$GEOSITE_SRC" ] && [ -n "$NIKKI_PKG" ]; then
	echo " "

	# 1. 把 GeoSite.dat 放进 nikki/files/run/（保留原文件名大小写）
	mkdir -p "$NIKKI_PKG/files/run"
	cp -f "$GEOSITE_SRC" "$NIKKI_PKG/files/run/$GEOSITE_NAME"

	# 2. patch nikki/Makefile 加 install 行（幂等：grep 查 INSTALL_DATA 行已存在则跳过）
	#    匹配 nikki/Makefile 里 `$(INSTALL_DIR) $(1)/etc/nikki/run` 那行后插入
	if ! grep -q "files/run/$GEOSITE_NAME" "$NIKKI_PKG/Makefile"; then
		sed -i "/^\t\$(INSTALL_DIR) \$(1)\/etc\/nikki\/run$/a\\\t\$(INSTALL_DATA) \$(CURDIR)\/files\/run\/$GEOSITE_NAME \$(1)\/etc\/nikki\/run\/$GEOSITE_NAME" "$NIKKI_PKG/Makefile"
	fi

	cd $PKG_PATH && echo "GeoSite.dat has been placed into nikki package!"
elif [ ! -f "$GEOSITE_SRC" ]; then
	echo " "
	echo "[skip] GeoSite.dat not found at $GEOSITE_SRC - put your file there to enable preinstall"
elif [ -z "$NIKKI_PKG" ]; then
	echo " "
	echo "[skip] nikki backend package not found in feeds/package - skipping GeoSite preinstall"
fi
