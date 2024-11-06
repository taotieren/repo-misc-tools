#!/bin/bash

# 仓库路径
REPO_PATH="/home/lilac/pkgs/aur-repo"

# 日志路径
LOG_PATH="/var/log/cleanup-repo-tool/cleanup.log"

# 保留的版本数量
KEEP_VERSIONS=2

# 确保日志目录存在
if [ ! -d "$(dirname "$LOG_PATH")" ]; then
    mkdir -p "$(dirname "$LOG_PATH")"
    chown root:root "$(dirname "$LOG_PATH")"
    chmod 755 "$(dirname "$LOG_PATH")"
fi

# 禁用回收站功能（如果适用）
export XDG_CONFIG_HOME=/dev/null

# 将日志输出重定向到日志文件
exec > >(tee -a "$LOG_PATH") 2>&1

# 记录开始时间
echo "Cleanup started at $(date)" >>"$LOG_PATH"

# 是否执行删除操作
DELETE=false
if [ "$1" == "-d" ]; then
    DELETE=true
fi

# 处理包版本的函数
handle_package_versions() {
    local PACKAGE_PREFIX=$1
    local ARCH_DIR=$2
    local KEEP_VERSIONS=$3

    # 获取包的所有版本
    VERSIONS=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "$PACKAGE_PREFIX-*.pkg.tar.zst" -printf "%f\n" | sort -V)

    # 保留指定数量的版本
    COUNT=0
    for VERSION in $VERSIONS; do
        if ((COUNT >= KEEP_VERSIONS)); then
            # 删除旧版本及其签名文件
            PKG_FILE="$ARCH_DIR/$VERSION"
            SIG_FILE="${PKG_FILE}.sig"
            if [ "$DELETE" = true ]; then
                rm -rf "$PKG_FILE" "$SIG_FILE"
                echo "Deleted: $PKG_FILE and $SIG_FILE"
            else
                echo "To be deleted: $PKG_FILE and $SIG_FILE"
            fi
        else
            COUNT=$((COUNT + 1))
        fi
    done
}

# 遍历所有架构目录
for ARCH in x86_64 any riscv64 aarch64; do
    ARCH_DIR="$REPO_PATH/$ARCH"

    # 获取所有包名
    PACKAGES=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.pkg.tar.zst" -printf "%f\n" | cut -d'-' -f1-2 | sort | uniq)

    # 用于存储已处理的包前缀
    PROCESSED_PREFIXES=()

    for PACKAGE in $PACKAGES; do
        # 提取包名的主名称和子版本
        IFS='-' read -r MAIN_NAME <<<"$PACKAGE"

        # 生成包前缀
        PACKAGE_PREFIX="${MAIN_NAME}"

        # 检查是否已经处理过该前缀
        if [[ " ${PROCESSED_PREFIXES[*]} " =~ " ${PACKAGE_PREFIX} " ]]; then
            continue
        fi

        # 添加到已处理的前缀列表
        PROCESSED_PREFIXES+=("$PACKAGE_PREFIX")

        # 处理该包前缀
        handle_package_versions "$PACKAGE_PREFIX" "$ARCH_DIR" "$DEFAULT_KEEP_VERSIONS"
    done
done

# 更新数据库
# if [ "$DELETE" = true ]; then
#     /usr/bin/repo-add "$REPO_PATH/db/x86_64/packages.db.tar.gz" "$REPO_PATH/x86_64"/*
#     /usr/bin/repo-add "$REPO_PATH/db/any/packages.db.tar.gz" "$REPO_PATH/any"/*
# fi

# 记录结束时间
echo "Cleanup finished at $(date)" >>"$LOG_PATH"
