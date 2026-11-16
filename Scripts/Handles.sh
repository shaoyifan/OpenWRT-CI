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
#FIX "theme-vantage" "$PACKAGE_PATH/luci-theme-vantage" sed -i \
#	-e '/^\/\* progress bars: thin track/,$ { /^\.cbi-progressbar::before {/,/^}/ { s/^[[:space:]]*font: 500 var(--fs-micro)\/1\.2 var(--mono);/\tfont: inherit; line-height: normal;/; } }' \
#	"$PACKAGE_PATH/luci-theme-vantage/luci-theme-vantage/htdocs/luci-static/vantage/vantage.css"

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"




# 添加并配置 luci-app-athena-led
ATHENA_LED_DIR="./package/emortal/luci-app-athena-led"
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



#
## --- 9. 精简 qualcommax 平台 cpuusage 脚本的 NSS 输出 ---
## 原输出: NSS: load 7% freq 748.8MHz
## 期望输出: NSS: 7%
#CPU_USAGE="./target/linux/qualcommax/base-files/sbin/cpuusage"
#if [ -f "$CPU_USAGE" ]; then
#	echo " "
#
#	# 把 "NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}" 简化为 "NSS: ${nss_load:-N/A}"
#	sed -i 's|NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}|NSS: ${nss_load:-N/A}|g' $CPU_USAGE
#
#	echo "cpuusage has been fixed!"
#fi
#
# --- 10. 首页概览：CPU 行只留 USR/SYS，新增 NSS、PPE 两个独立行（百分比放最前） ---
SYS_10="./feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$SYS_10" ] && ! grep -q "cuNss" "$SYS_10"; then
	echo " "

	# 在 var fields = [ 前插入解析代码。全部用字符串切分，不做任何加工：NSS/PPE 段按原样显示
	awk '/var fields = \[/ && !done {
		print "\t\tvar cu     = cpuusage.cpuusage || \"\";"
		print "\t\tvar cuMain = cu.split(\" PPE:\")[0].trim();"
		print "\t\tvar cuRest = cu.indexOf(\"PPE:\") >= 0 ? cu.slice(cu.indexOf(\"PPE:\")) : null;"
		print "\t\tvar cuNss = null, cuPpe = null;"
		print "\t\tif (cuRest) {"
		print "\t\t\tvar seg = cuRest.split(\" NSS:\");"
		print "\t\t\tcuPpe = seg[0].trim().slice(4).trim();"
		print "\t\t\tif (seg[1])"
		print "\t\t\t\tcuNss = seg[1].trim();"
		print "\t\t}"
		done = 1
	}
	{ print }' "$SYS_10" > "$SYS_10.tmp" && mv "$SYS_10.tmp" "$SYS_10"

	# CPU 行只显示 USR/SYS；紧跟 NSS、PPE 两个独立行，数组最后一项不带尾逗号
	sed -i "s#_('CPU usage (%)'),[[:space:]]*cpuusage\\.cpuusage#_('CPU usage (%)'),        cuMain,\t\t\t_('NSS'),                cuNss,\t\t\t_('PPE'),                cuPpe#" "$SYS_10"

	echo "10_system.js has been split (CPU + NSS + PPE)!"
fi

# --- 11. 预置 GeoSite.dat 到 nikki 后端包（编译后镜像自带，免去 mihomo 首次启动下载）---
# 源：Scripts/patches/nikki/GeoSite.dat（你自己放进去的文件，文件名大小写保留）
# 目标：nikki/files/run/GeoSite.dat → ipk install 时释放到镜像 /etc/nikki/run/GeoSite.dat
# 关键修正：GeoSite.dat 不是 luci-app-nikki（纯前端包）的事，是 nikki 后端包 + mihomo 内核的事
GEOSITE_SRC="$(dirname "$0")/patches/nikki/GeoSite.dat"
GEOSITE_NAME="$(basename "$GEOSITE_SRC")"
# 精确锁定 nikki 后端包：grep PKG_NAME:=nikki 排除 luci-app-nikki 干扰
NIKKI_PKG=$(find ./feeds/luci/applications ./feeds/packages ./package -maxdepth 6 -name "Makefile" 2>/dev/null | xargs grep -l "^PKG_NAME:=nikki$" 2>/dev/null | head -1 | xargs dirname)

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

	echo "GeoSite.dat has been placed into nikki package!"
elif [ ! -f "$GEOSITE_SRC" ]; then
	echo " "
	echo "[skip] GeoSite.dat not found at $GEOSITE_SRC - put your file there to enable preinstall"
elif [ -z "$NIKKI_PKG" ]; then
	echo " "
	echo "[skip] nikki backend package not found in feeds/package - skipping GeoSite preinstall"
fi

# --- 12. 拉取 honk main 源码并钉版本（官方 openwrt-packages 配方要求源码预置在 honk/src）---
# 背景：daeuniverse/openwrt-packages 的 honk 包不带源码，Build/Prepare 硬性要求 honk/src
#       存在，缺失直接 exit 1；版本默认钉 v0.1.0-beta.6，但 PKG_VERSION/HONK_GIT_TAG 可覆盖。
# 做法：clone honk main HEAD 进 src，把 HONK_GIT_TAG 钉成 main-<commit>，
#       面板的"构建"哈希来自源码 checkout（git rev-parse HEAD），如实反映实际构建的代码。
#       工具链（rustup stable/nightly + bpf-linker）由 prepare-honk-toolchain.sh 在 workflow 中准备。
HONK_PKG="$PACKAGE_PATH/openwrt-packages/honk"

if [ ! -f "$HONK_PKG/Makefile" ]; then
	echo " "
	echo "[skip] honk package not found - skipping honk source checkout"
elif ! grep -qs "^CONFIG_PACKAGE_luci-app-honk=y" ./Config/*.txt "${GITHUB_WORKSPACE:-.}"/Config/*.txt; then
	echo " "
	echo "[skip] honk not enabled in any config - skipping honk source checkout"
else
	echo " "

	if [ -d "$HONK_PKG/src/.git" ]; then
		# 重跑场景：更新到当前 main HEAD
		if git -C "$HONK_PKG/src" fetch --depth=1 origin main -q &&
			git -C "$HONK_PKG/src" reset --hard -q FETCH_HEAD; then
			echo "honk source updated to current main!"
		else
			echo "[warn] honk source update failed - keeping existing checkout"
		fi
	elif git clone --depth=1 --branch main https://github.com/daeuniverse/honk "$HONK_PKG/src"; then
		echo "honk source cloned from main!"
	else
		echo "[warn] honk source clone failed - build will fail with 'the source tree is missing'"
	fi

	HONK_COMMIT=$(git -C "$HONK_PKG/src" rev-parse --short=7 HEAD 2>/dev/null || true)
	if [ -n "$HONK_COMMIT" ]; then
		# 只覆盖 HONK_GIT_TAG（进 GITHUB_REF，面板显示的版本字符串），不动 PKG_VERSION，
		# 避免 apk 对版本号的语法校验被自定义字符串绊住
		sed -i "s/^HONK_GIT_TAG:=.*/HONK_GIT_TAG:=main-${HONK_COMMIT}/" "$HONK_PKG/Makefile"
		echo "honk source pinned to main@${HONK_COMMIT}!"
	else
		echo "[warn] cannot resolve honk commit - Makefile left at default v0.1.0-beta.6 pin"
	fi
fi

# --- 13. honk 密钥文件 auth.dae 加入 sysupgrade 保留列表 ---
# 背景：config.dae 的 experimental.native_api/clash_api 里出现 secret: 后，honk 把该文件
#       标记为含凭据、doona 拒绝写回，secret 须拆进 include 引用的 /etc/honk/auth.dae；
#       但 honk 包 conffiles 只含 /etc/config/honk 与 /etc/honk/config.dae，keep.d 只保
#       /etc/honk/data/，手工新建的 auth.dae 保留配置刷机必丢。这里把路径写进 base-files
#       的 /etc/sysupgrade.conf（该文件在 owrt 里只是注释模板，覆盖安全；写法幂等）。
SYS_CONF="./package/base-files/files/etc/sysupgrade.conf"
if [ -f "$SYS_CONF" ]; then
	echo " "

	if grep -qs "^/etc/honk/auth.dae$" "$SYS_CONF"; then
		echo "sysupgrade.conf already keeps /etc/honk/auth.dae!"
	else
		echo "/etc/honk/auth.dae" >> "$SYS_CONF"
		echo "sysupgrade.conf now keeps /etc/honk/auth.dae!"
	fi
else
	echo " "
	echo "[skip] base-files sysupgrade.conf not found - auth.dae will NOT survive sysupgrade"
fi
