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
REPO_URL="https://github.com/Sh1rokoDev/luci-app-athena-led.git"
TEMP_DIR="athena_led_temp"

# 彻底清理旧目录和临时目录
rm -rf "$ATHENA_LED_DIR" "$TEMP_DIR" 2>/dev/null

# 克隆到临时目录
if git clone -b LuCI2-JS --depth=1 "$REPO_URL" "$TEMP_DIR"; then
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
	cp -f "$GITHUB_WORKSPACE/Scripts/patches/athena/athena-led" "$ATHENA_LED_DIR/root/usr/sbin/athena-led"
    # 再次确认并设置执行权限
    # 注意：如果子文件夹里路径有变化，请检查这里
    [ -f "$ATHENA_LED_DIR/root/usr/sbin/athena-led" ] && chmod +x "$ATHENA_LED_DIR/root/usr/sbin/athena-led"
    [ -f "$ATHENA_LED_DIR/root/etc/init.d/athena_led" ] && chmod +x "$ATHENA_LED_DIR/root/etc/init.d/athena_led"

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



# --- 10. 修复 nlbwmon 流量统计 (重载 nf_conntrack 模块) ---
NLBWMON_INIT="../feeds/packages/net/nlbwmon/files/nlbwmon.init"

if [ -f "$NLBWMON_INIT" ]; then
    echo " "

    # 检查是否已经修改过，避免重复添加
    if ! grep -q "rmmod nf_conntrack_netlink" "$NLBWMON_INIT"; then
        # 在 start_service() { 这一行之后插入两行命令
        sed -i '/start_service() {/a \	rmmod nf_conntrack_netlink\n	modprobe nf_conntrack_netlink' "$NLBWMON_INIT"
        
        echo "nlbwmon init script has been fixed!"
    else
        echo "nlbwmon init script is already patched."
    fi
fi


# --- XX. 逆向修复 netdata 因上游翻车导致的编译失败 ---
NETDATA_MAKEFILE="../feeds/packages/admin/netdata/Makefile"

if [ -f "$NETDATA_MAKEFILE" ]; then
    echo " "

    # 1. 检查是否是翻车的第 4 版，如果是，强行降回第 3 版
    if grep -q "PKG_RELEASE:=4" "$NETDATA_MAKEFILE"; then
        sed -i 's/PKG_RELEASE:=4/PKG_RELEASE:=3/g' "$NETDATA_MAKEFILE"
        echo "netdata PKG_RELEASE has been reverted to 3."
    fi

    # 2. 检查并移除惹祸的 -std=gnu17 参数，恢复成原本的 -O3 结尾
    if grep -q "\-std=gnu17" "$NETDATA_MAKEFILE"; then
        # 将包含 -std=gnu17 的那一行整行替换回原本安全的编译参数
        sed -i 's/TARGET_CFLAGS := \$(filter-out -O%,\$(TARGET_CFLAGS)) -O3 -std=gnu17/TARGET_CFLAGS := \$(filter-out -O%,\$(TARGET_CFLAGS)) -O3/g' "$NETDATA_MAKEFILE"
        echo "netdata gnu17 compiler flag has been removed."
    fi
fi