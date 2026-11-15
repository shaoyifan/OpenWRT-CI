#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# 为 honk（daeuniverse/openwrt-packages 官方配方）准备构建机工具链。
# 官方 build.sh 不需要 zig（用 OpenWrt cross gcc wrapper 替代），但需要：
#   - rustup：按源码内 rust-toolchain.toml 钉的 stable + nightly（rustup 自动安装）
#   - bpf-linker：prebuilt，版本与 sha256 从 honk 源码的 .github/ci/pins.env 解析
#   - 宿主包：libclang（bindgen）、cmake（BoringSSL）、clang、zstd（解压 bpf-linker）
set -euo pipefail

# 没选 honk 就跳过（只有启用了 honk 的配置才付工具链成本）
grep -qs '^CONFIG_PACKAGE_honk=y' .config || { echo "honk not selected, skip honk toolchain"; exit 0; }

HONK_SRC_PKG="$PWD/package/openwrt-packages/honk"
PINS="$HONK_SRC_PKG/src/.github/ci/pins.env"

# 版本从 honk 源码的 pins.env 解析：源码换 tag/commit 后工具链版本自动跟随
BPF_LINKER_VERSION=$(sed -n 's/^BPF_LINKER_VERSION=//p' "$PINS" 2>/dev/null | head -n 1)
BPF_LINKER_SHA256=$(sed -n 's/^BPF_LINKER_SHA256=//p' "$PINS" 2>/dev/null | head -n 1)
BPF_LINKER_VERSION="${BPF_LINKER_VERSION:-0.11.0}"
BPF_LINKER_SHA256="${BPF_LINKER_SHA256:-10f62ba9ab7e544d538370552660efcb4f1a19153d5752bbf0f6b51f3bada450}"
echo "honk pins: bpf-linker $BPF_LINKER_VERSION"

# 宿主依赖（runner 大多自带，缺哪样装哪样）
NEED_APT=0
command -v cmake >/dev/null 2>&1 || NEED_APT=1
command -v clang >/dev/null 2>&1 || NEED_APT=1
command -v zstd >/dev/null 2>&1 || NEED_APT=1
ldconfig -p 2>/dev/null | grep -q libclang || NEED_APT=1
if [ "$NEED_APT" = 1 ]; then
	sudo apt-get update -qq
	sudo apt-get install -y --no-install-recommends clang libclang-dev cmake zstd
fi

# rustup：runner 自带（prepare-rust.sh 已校验存在），这里把 honk 钉的两个工具链预热好，
# 否则首次 make 会在编译 honk 时现场下载，日志混在 make 输出里
RUSTUP_BIN=$(command -v rustup || true)
if [ -z "$RUSTUP_BIN" ]; then
	for candidate in "$HOME/.cargo/bin/rustup" /usr/bin/rustup; do
		if [ -x "$candidate" ]; then RUSTUP_BIN=$candidate; break; fi
	done
fi
if [ -n "$RUSTUP_BIN" ]; then
	PATH="$(dirname "$RUSTUP_BIN"):$PATH"
	export PATH
	for toml in "$HONK_SRC_PKG/src/rust-toolchain.toml" \
		"$HONK_SRC_PKG/src/crates/honk-ebpf/rust-toolchain.toml"; do
		if [ -f "$toml" ]; then
			TC=$(awk -F'"' '/^[[:space:]]*channel[[:space:]]*=/{print $2; exit}' "$toml")
			if [ -n "$TC" ]; then
				echo "Installing honk pinned Rust toolchain: $TC"
				rustup toolchain install "$TC" --profile minimal
			fi
		else
			echo "WARNING: $toml not found - honk source missing? (Handles.sh step 12)"
		fi
	done
else
	echo "WARNING: rustup missing - honk build will fail"
fi

# bpf-linker（prebuilt 二进制，tarball 内是裸文件，直接解到 /usr/local/bin）
if [ "$(bpf-linker --version 2>/dev/null | awk '{print $2}')" != "$BPF_LINKER_VERSION" ]; then
	HONK_TMP=$(mktemp -d)
	URL="https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
	curl -fsSL -o "$HONK_TMP/bpf-linker.tar.zst" "$URL"
	echo "${BPF_LINKER_SHA256}  ${HONK_TMP}/bpf-linker.tar.zst" | sha256sum -c -
	sudo tar --zstd -xf "$HONK_TMP/bpf-linker.tar.zst" -C /usr/local/bin
	rm -rf "$HONK_TMP"
fi
bpf-linker --version

# 诊断：若真 vmlinux-btf 被选中而没传 BTF blob，Build/Prepare 会在编译期报错
if grep -qs '^CONFIG_PACKAGE_vmlinux-btf=y' .config; then
	echo "WARNING: real vmlinux-btf selected but no VMLINUX_BTF_SRC blob - use vmlinux-btf-builtin (kernel BTF) instead!"
fi
