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

# --- 12. 预置 honk 预编译核心（免去宿主机 zig / bpf-linker / rust nightly 工具链）---
# 背景：honk/Makefile 在 files/honk-core.bin 不存在时会调 build_honk_core.sh 现场编译，
#       硬性依赖 zig（版本须精确匹配 Makefile 钉的 pin）+ bpf-linker + rustup nightly/rust-src，
#       而 build_honk_core.sh 对"有 bin、无 .stamp"直接判定为预编译产物并跳过编译。
# 做法：从 QiuSimons 同版本 release 取出已编好的 honk-core，预置到 honk/files/honk-core.bin
HONK_MK="$PACKAGE_PATH/luci-app-honk/honk/Makefile"
HONK_BIN="$PACKAGE_PATH/luci-app-honk/honk/files/honk-core.bin"

if [ ! -f "$HONK_MK" ]; then
	echo " "
	echo "[skip] honk package not found - skipping honk-core seed"
elif [ -f "$HONK_BIN" ] && [ -f "$HONK_BIN.stamp" ]; then
	echo " "
	echo "[skip] honk-core already built from source - skipping honk-core seed"
elif ! grep -qs "^CONFIG_PACKAGE_luci-app-honk=y" ./Config/*.txt "${GITHUB_WORKSPACE:-.}"/Config/*.txt; then
	echo " "
	echo "[skip] honk not enabled in any config - skipping honk-core seed"
else
	echo " "

	# 目标架构：honk 仅支持 aarch64_generic / x86_64，WRT_TARGET 由 workflow 写入环境
	HONK_ARCH="aarch64_generic"
	[ "${WRT_TARGET:-}" = "x86" ] && HONK_ARCH="x86_64"

	# tag 规则 honk_${PKG_VERSION(把 ~ 换成 _)}-r${PKG_RELEASE}；不拼文件名，按 API 挑 asset
	HONK_VER=$(sed -n 's/^PKG_VERSION:=//p' "$HONK_MK" | head -n 1)
	HONK_REL=$(sed -n 's/^PKG_RELEASE:=//p' "$HONK_MK" | head -n 1)
	HONK_TAG="honk_$(echo "$HONK_VER" | tr '~' '_')-r${HONK_REL:-1}"
	HONK_URL=$(curl -sL "https://api.github.com/repos/QiuSimons/luci-app-honk/releases/tags/$HONK_TAG" |
		jq -r '.assets[]?.browser_download_url' 2>/dev/null | grep -m 1 "_${HONK_ARCH}-openwrt-.*\.ipk$")

	if [ -z "$HONK_URL" ]; then
		echo "[skip] no honk release asset for $HONK_TAG ($HONK_ARCH) - build will need zig + bpf-linker"
	else
		HONK_TMP=$(mktemp -d)
		HONK_PACK=1

		curl -fsSL -o "$HONK_TMP/honk.ipk" "$HONK_URL" || HONK_PACK=0

		# 解包：ipk 可能是 gzip tar（OpenWrt SDK 24.10 产物），也可能是 ar，两种都试
		if [ "$HONK_PACK" = 1 ] && ! tar -xzf "$HONK_TMP/honk.ipk" -C "$HONK_TMP" 2>/dev/null; then
			(cd "$HONK_TMP" && ar x honk.ipk) || HONK_PACK=0
		fi

		# 成员名带 ./ 前缀（./data.tar.gz），必须按完整名取
		if [ "$HONK_PACK" = 1 ] &&
			tar -xzf "$HONK_TMP/data.tar.gz" -C "$HONK_TMP" ./usr/bin/honk-core; then
			install -m755 "$HONK_TMP/usr/bin/honk-core" "$HONK_BIN"
			rm -f "$HONK_BIN.stamp"

			# ELF e_machine 自检：aarch64 = b7 00，x86_64 = 3e 00
			# build_honk_core.sh 只看"有 bin 无 stamp"，不校验架构，错配会被静默接受
			HONK_MACH=$(od -An -tx1 -j18 -N2 "$HONK_BIN" | tr -d ' \n')
			case "$HONK_ARCH:$HONK_MACH" in
				aarch64_generic:b700 | x86_64:3e00)
					echo "honk-core ($HONK_ARCH) seeded from $HONK_TAG!"
					;;
				*)
					rm -f "$HONK_BIN"
					echo "[skip] honk-core ELF mismatches $HONK_ARCH ($HONK_MACH) - build will need zig + bpf-linker"
					;;
			esac
		else
			echo "[skip] seed honk-core failed - build will need zig + bpf-linker"
		fi

		rm -rf "$HONK_TMP"
	fi
fi
