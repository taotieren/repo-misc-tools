#!/bin/bash

# 仓库路径
REPO_PATH="/home/lilac/pkgs/aur-repo"

# 日志路径
LOG_PATH="/var/log/cleanup-repo/cleanup.log"

# 禁用回收站功能（如果适用）
export XDG_CONFIG_HOME=/dev/null

# 将日志输出重定向到日志文件
exec > >(tee -a "$LOG_PATH") 2>&1

# 记录开始时间
echo "Cleanup started at $(date)" >>"$LOG_PATH"

# 保留的版本数量
KEEP_VERSIONS=2

# 遍历所有架构目录
for ARCH in x86_64 any riscv64 aarch64; do
    ARCH_DIR="$REPO_PATH/$ARCH"

    # 获取所有包名
    PACKAGES=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name"*.pkg.tar.zst" -printf "%f\n" | cut -d'-' -f1-2 | sort | uniq)

    for PACKAGE in $PACKAGES; do
        # 获取包的所有版本
        VERSIONS=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "$PACKAGE-*.pkg.tar.zst" -printf "%f\n" | sort -rV)

        # 保留最新的两个版本
        COUNT=0
        for VERSION in $VERSIONS; do
            if ((COUNT >= KEEP_VERSIONS)); then
                # 删除旧版本及其签名文件
                PKG_FILE="$ARCH_DIR/$VERSION"
                SIG_FILE="${PKG_FILE}.sig"
                rm -rf "$PKG_FILE" "$SIG_FILE"
                echo "Deleted: $PKG_FILE and $SIG_FILE"
            else
                COUNT=$((COUNT + 1))
            fi
        done
    done
done

# 更新数据库
#repo-add "$REPO_PATH/db/x86_64/packages.db.tar.gz" "$REPO_PATH/x86_64"/*
#repo-add "$REPO_PATH/db/any/packages.db.tar.gz" "$REPO_PATH/any"/*

# 记录结束时间
echo "Cleanup finished at $(date)" >>"$LOG_PATH"
