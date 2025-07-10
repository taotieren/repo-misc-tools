#!/bin/bash
# 仓库清理工具 - 支持多架构包保留策略
# 功能：清理指定目录中旧版本包文件，保留最新N个版本

# ========== 配置区 ==========
REPO_PATH="/home/lilac/pkgs/aur-repo"      # 仓库根目录
LOG_PATH="/var/log/cleanup-repo-tool/cleanup.log"  # 日志路径
MAX_KEEP=2                                # 默认保留版本数
DRY_RUN=true                              # 默认为模拟模式
UPDATE_DB=false                           # 默认不更新数据库

# ========== 日志目录安全创建 ==========
ensure_log_dir() {
    local log_dir=$(dirname "$LOG_PATH")
    
    # 检查并创建日志目录
    if [ ! -d "$log_dir" ]; then
        echo "创建日志目录: $log_dir"
        if ! mkdir -p "$log_dir"; then
            echo "错误：无法创建日志目录！" >&2
            exit 1
        fi
        
        # 设置目录权限
        chown root:root "$log_dir"
        chmod 755 "$log_dir"
        echo "目录权限已设置：$(stat -c '%A %U:%G' "$log_dir")"
    fi
    
    # 确保日志文件存在
    touch "$LOG_PATH"
    chmod 644 "$LOG_PATH"
}

# ========== 日志记录函数 ==========
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_PATH" >/dev/null
}

# ========== 参数解析 ==========
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--delete)
                DRY_RUN=false
                log "启用实际删除模式"
                shift ;;
            --update-db)
                UPDATE_DB=true
                log "启用数据库更新"
                shift ;;
            -k|--keep)
                MAX_KEEP="$2"
                if ! [[ "$MAX_KEEP" =~ ^[0-9]+$ ]]; then
                    log "错误：保留版本数必须为整数"
                    exit 1
                fi
                log "设置保留版本数: $MAX_KEEP"
                shift 2 ;;
            *)
                log "未知参数: $1"
                exit 1 ;;
        esac
    done
}

# ========== 包名提取函数 ==========
extract_pkgname() {
    local filename=$(basename "$1")
    # 移除扩展名和版本/架构部分
    echo "${filename%-*-*-*.pkg.tar.zst}"
}

# ========== 核心清理逻辑 ==========
clean_architecture_dir() {
    local arch_dir="$1"
    log "处理架构目录: $(basename "$arch_dir")"
    
    declare -A packages  # 存储包名与文件列表的映射
    
    # 收集所有包文件并按包名分组
    while IFS= read -r pkg_file; do
        pkg_name=$(extract_pkgname "$pkg_file")
        packages["$pkg_name"]+="$pkg_file|"
    done < <(find "$arch_dir" -maxdepth 1 -type f -name "*.pkg.tar.zst" ! -name "*.sig")
    
    # 处理每个包
    for pkg_name in "${!packages[@]}"; do
        IFS='|' read -ra versions <<< "${packages[$pkg_name]%|}"
        local count=${#versions[@]}
        
        # 检查是否需要清理
        if (( count <= MAX_KEEP )); then
            log "跳过 $pkg_name - 只有 $count 个版本 (需$((MAX_KEEP+1))个以上才清理)"
            continue
        fi
        
        # 按修改时间排序（最新在前）
        sorted_versions=($(ls -t "${versions[@]}"))
        
        # 计算需删除的旧版本
        local delete_count=$((count - MAX_KEEP))
        local delete_list=("${sorted_versions[@]: -delete_count}")
        
        # 执行删除操作
        for file in "${delete_list[@]}"; do
            if [[ "$DRY_RUN" == true ]]; then
                log "[DRY-RUN] 将删除: $(basename "$file")"
            else
                log "删除旧版本: $(basename "$file")"
                rm -f "$file"
                # 同步删除签名文件
                local sig_file="${file}.sig"
                [[ -f "$sig_file" ]] && rm -f "$sig_file"
            fi
        done
    done
}

# ========== 数据库更新函数 ==========
update_repo_database() {
    [[ "$UPDATE_DB" == false ]] && return
    [[ "$DRY_RUN" == true ]] && {
        log "[DRY-RUN] 跳过数据库更新"
        return
    }
    
    log "开始更新数据库..."
    for arch_dir in "$REPO_PATH"/*; do
        [[ -d "$arch_dir" ]] || continue
        local arch_name=$(basename "$arch_dir")
        local db_file="$REPO_PATH/$arch_name/aur-repo.db.tar.gz"
        
        # 确保数据库目录存在
        mkdir -p "$(dirname "$db_file")"
        
        # 使用repo-add更新数据库
        if repo-add -R "$db_file" "$arch_dir"/*.pkg.tar.zst; then
            log "成功更新 $arch_name 架构数据库"
        else
            log "错误：$arch_name 数据库更新失败"
        fi
    done
}

# ========== 主流程 ==========
main() {
    ensure_log_dir
    parse_arguments "$@"
    log "===== 仓库清理开始 ====="
    log "仓库路径: $REPO_PATH"
    log "保留版本数: $MAX_KEEP"
    $DRY_RUN && log "模式: DRY-RUN (模拟操作)"
    
    # 遍历所有架构目录
    for arch_dir in "$REPO_PATH"/*; do
        [[ -d "$arch_dir" ]] && clean_architecture_dir "$arch_dir"
    done
    
    update_repo_database
    log "===== 清理完成 ====="
}

# 入口执行
main "$@"
