#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
# if [ -d *"luci-theme-argon"* ]; then
# 	echo " "

# 	cd ./luci-theme-argon/

# 	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

# 	cd $PKG_PATH && echo "theme-argon has been fixed!"
# fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

# 添加并配置 luci-app-athena-led
ATHENA_LED_DIR="../package/emortal/luci-app-athena-led"
REPO_URL="https://github.com/xiaren2/JDC-AX6600-Athena-LED-Controller.git"
TEMP_DIR="athena_led_temp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 彻底清理旧目录和临时目录
rm -rf "$ATHENA_LED_DIR" "$TEMP_DIR" 2>/dev/null

# 克隆到临时目录
if git clone -b js --depth=1 "$REPO_URL" "$TEMP_DIR"; then
    echo " "

    # 将子文件夹里的内容移动到目标位置
    # 假设子文件夹名也是 luci-app-athena-led
    mkdir -p "$ATHENA_LED_DIR"
    cp -r "$TEMP_DIR/luci-app-athena-led/"* "$ATHENA_LED_DIR/"
    rm -rf "$TEMP_DIR"

    # === 用标准化 luci.mk 版 Makefile 覆盖 xiaren2 上游手写 Makefile ===
    # 背景：xiaren2 js 分支 Makefile 是 include package.mk + 手写 install 段，
    #       漏装了 root/usr/share/rpcd/acl.d/*.json（导致 web 调 uci 报 RPCError EPERM）
    # 我们的 patches/athena/Makefile 用 include $(TOPDIR)/feeds/luci/luci.mk 模板，
    # luci.mk 会自动 install root/ 下所有内容（包括 acl.d）— ACL bug 自愈，无需 sed 注入。
    OVERRIDE_MK="$SCRIPT_DIR/patches/athena/Makefile"
    if [ -f "$OVERRIDE_MK" ]; then
        cp -f "$OVERRIDE_MK" "$ATHENA_LED_DIR/Makefile"
        echo "[OK] Makefile replaced with luci.mk version (auto ACL install)"
    else
        echo "[WARN] $OVERRIDE_MK not found - keeping xiaren2 upstream Makefile"
    fi

    echo "luci-app-athena-led has been added and fixed!"
fi


# 修复 AdGuardHome 翻译
ADG_PATH="../feeds/luci/applications/luci-app-adguardhome"
PATCH_PO="$GITHUB_WORKSPACE/Scripts/patches/adg/po"

if [ -d "$ADG_PATH" ]; then
    echo " "

    # 复制翻译文件
    cp -rf "$PATCH_PO"/* "$ADG_PATH/po/"

    echo "luci-app-adguardhome translations have been fixed!"
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

 
# --- 9. 精简 qualcommax 平台 cpuusage 脚本的 NSS 输出 ---
# 原输出: NSS: load 7% freq 748.8MHz
# 期望输出: NSS: 7%
CPU_USAGE="../target/linux/qualcommax/base-files/sbin/cpuusage"
if [ -f "$CPU_USAGE" ]; then
	echo " "

	# 把 "NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}" 简化为 "NSS: ${nss_load:-N/A}"
	sed -i 's|NSS: load ${nss_load:-N/A} freq ${nss_freq:-N/A}|NSS: ${nss_load:-N/A}|g' $CPU_USAGE

	cd $PKG_PATH && echo "cpuusage has been fixed!"
fi

# --- 10. 把 LuCI 状态页的 CPU 使用率拆成两行（CPU / NSS ECM） ---
SYS_10="../feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$SYS_10" ]; then
	echo " "

	# 步骤 1：在 var fields = [ 之前插入 4 行解析代码（cuMain / cuEcm）
	sed -i "/var fields = \[/i\\
	\\tvar cu = cpuusage.cpuusage || \"?\";\\
	\\tvar m  = cu.match(/tcp\\\\s+\\\\d+.*total\\\\s+\\\\d+/);\\
	\\tvar cuMain = m ? cu.replace(/\\\\s*tcp\\\\s+\\\\S+.*\$/, \"\") : cu;\\
	\\tvar cuEcm  = m ? m[0] : null;\\

	" "$SYS_10"

	# 步骤 2：把 _('CPU usage (%)'), cpuusage.cpuusage 拆成两行（自动多渲染一行 ecm）。
	# 加 /var cuMain/! 前缀做幂等：已打过补丁的文件里没有 cpuusage.cpuusage，匹配为空，sed 不会重写
	sed -i "/var cuMain/!s#_('CPU usage (%)'),[[:space:]]*cpuusage\\.cpuusage#_('CPU usage (%)'),        cuMain,\\n\\t\\t\\t_('NSS ECM 连接数'),        cuEcm || '?',#" "$SYS_10"

	cd $PKG_PATH && echo "10_system.js has been split!"
fi

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
