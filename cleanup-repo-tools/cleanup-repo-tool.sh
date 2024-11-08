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
    VERSIONS=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "${PACKAGE_PREFIX}*.pkg.tar.zst" -printf "%f\n" |
        sed -E 's/^.*-([0-9]+)\..*$/\1/' | sort -V)

    # 保留最新的 KEEP_VERSIONS 个版本
    local VERSION_COUNT=${#VERSIONS[@]}
    if ((VERSION_COUNT > KEEP_VERSIONS)); then
        OLDEST_VERSION=${VERSIONS[0]}
        DELETE_VERSIONS=("${VERSIONS[@]:0:$((VERSION_COUNT - KEEP_VERSIONS))}")

        for DELETE_VERSION in "${DELETE_VERSIONS[@]}"; do
            PKG_FILES=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "${PACKAGE_PREFIX}-${DELETE_VERSION}.*.pkg.tar.zst")
            for PKG_FILE in $PKG_FILES; do
                SIG_FILE="${PKG_FILE}.sig"
                if [ "$DELETE" = true ]; then
                    rm -f "$PKG_FILE" "$SIG_FILE"
                    echo "Deleted: $PKG_FILE and $SIG_FILE"
                else
                    echo "To be deleted: $PKG_FILE and $SIG_FILE"
                fi
            done
        done
    else
        echo "Not enough versions of $PACKAGE_PREFIX to delete. Skipping."
    fi
    #     # 检查版本数量是否足够
    #     VERSION_COUNT=$(echo "$VERSIONS" | wc -l)
    #     if ((VERSION_COUNT <= KEEP_VERSIONS)); then
    #         echo "Not enough versions of $PACKAGE_PREFIX to delete. Skipping."
    #         return
    #     fi

    # 保留最新的 KEEP_VERSIONS 个版本
    #     local KEEP_COUNT=0
    #     for VERSION in $VERSIONS; do
    #         if ((KEEP_COUNT < KEEP_VERSIONS)); then
    #             KEEP_COUNT=$((KEEP_COUNT + 1))
    #             continue
    #         fi
    #
    #         # 删除旧版本及其签名文件
    #         PKG_FILES=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "${PACKAGE_PREFIX}-${VERSION%%-*}-*-${VERSION##*-}.pkg.tar.zst")
    #         for PKG_FILE in $PKG_FILES; do
    #             SIG_FILE="${PKG_FILE}.sig"
    #             if [ "$DELETE" = true ]; then
    #                 rm -f "$PKG_FILE" "$SIG_FILE"
    #                 echo "Deleted: $PKG_FILE and $SIG_FILE"
    #             else
    #                 echo "To be deleted: $PKG_FILE and $SIG_FILE"
    #             fi
    #         done
    #     done
}

# 遍历所有架构目录
for ARCH in aarch64 any riscv64 x86_64; do
    ARCH_DIR="$REPO_PATH/$ARCH"

    # 获取所有包名
    PACKAGES=$(find "$ARCH_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.pkg.tar.zst" -printf "%f\n" |
        sed -E 's/^(.*?)-[0-9].*/\1/' | sort | uniq)

    # 用于存储已处理的包前缀
    PROCESSED_PREFIXES=()

    for PACKAGE in $PACKAGES; do
        # 生成包前缀
        PACKAGE_PREFIX="${PACKAGE}"

        # 检查是否已经处理过该前缀
        if [[ " ${PROCESSED_PREFIXES[*]} " =~ " ${PACKAGE_PREFIX} " ]]; then
            continue
        fi

        # 添加到已处理的前缀列表
        PROCESSED_PREFIXES+=("$PACKAGE_PREFIX")

        # 处理该包前缀
        handle_package_versions "$PACKAGE_PREFIX" "$ARCH_DIR" "$KEEP_VERSIONS"
    done
done

# 更新数据库
# 使用 archrepo 服务进行数据库更新
# if [ "$DELETE" = true ]; then
#     for ARCH in aarch64 any riscv64 x86_64; do
#         ARCH_DIR="$REPO_PATH/$ARCH"
#         DB_FILE="$REPO_PATH/db/$ARCH/packages.db.tar.gz"
#         repo-add "$DB_FILE" "$ARCH_DIR"/*.pkg.tar.zst
#     done
# fi

# 记录结束时间
echo "Cleanup finished at $(date)" >>"$LOG_PATH"
