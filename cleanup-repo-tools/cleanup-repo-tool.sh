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
    local ARCH_DIR=$1
    local KEEP_VERSIONS=$2

    # 遍历所有包
    for PACKAGE_FILE in "$ARCH_DIR"/*.pkg.tar.zst; do
        PACKAGE_NAME=$(basename "$PACKAGE_FILE" .pkg.tar.zst)

        # 获取包的所有版本
        VERSIONS=$(ls -1 "$ARCH_DIR/$PACKAGE_NAME"-*.pkg.tar.zst 2>/dev/null | sort -V)

        # 检查是否存在版本
        if [ -z "$VERSIONS" ]; then
            echo "Not enough versions of $PACKAGE_NAME to delete. Skipping."
            continue
        fi

        # 保留最新的 KEEP_VERSIONS 个版本
        VERSION_COUNT=$(echo "$VERSIONS" | wc -l)
        if ((VERSION_COUNT > KEEP_VERSIONS)); then
            DELETE_VERSIONS=$(echo "$VERSIONS" | head -n -$KEEP_VERSIONS)

            for DELETE_VERSION in $DELETE_VERSIONS; do
                if [ "$DELETE" = true ]; then
                    rm -f "$DELETE_VERSION"
                    rm -f "${DELETE_VERSION%.pkg.tar.zst}.sig"
                    echo "Deleted: $DELETE_VERSION and ${DELETE_VERSION%.pkg.tar.zst}.sig"
                else
                    echo "To be deleted: $DELETE_VERSION and ${DELETE_VERSION%.pkg.tar.zst}.sig"
                fi
            done
        else
            echo "Not enough versions of $PACKAGE_NAME to delete. Skipping."
        fi
    done
}
# 遍历所有架构目录
for ARCH in aarch64 any riscv64 x86_64; do
    ARCH_DIR="$REPO_PATH/$ARCH"

    # 处理该架构目录下的包
    handle_package_versions "$ARCH_DIR" "$KEEP_VERSIONS"

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
