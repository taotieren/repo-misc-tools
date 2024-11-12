import os
import re
import sys
from collections import defaultdict
from datetime import datetime

# 仓库路径
REPO_PATH = "/home/lilac/pkgs/aur-repo"
# 保留的版本数量
KEEP_VERSIONS = 2
# 日志路径
LOG_PATH = "/var/log/cleanup-repo-tool/cleanup.log"
# 判断是否执行删除操作
DELETE = "-d" in sys.argv

# 确保日志目录存在
log_dir = os.path.dirname(LOG_PATH)
if not os.path.exists(log_dir):
    os.makedirs(log_dir, mode=0o755, exist_ok=True)
    os.chown(log_dir, 0, 0)  # root:root ownership


# 自定义版本解析函数
def parse_version(version_str):
    # 将版本号拆分成数字和非数字部分
    parts = re.split(r"(\d+)", version_str)
    # 将数字部分转换为整数，非数字部分保持为字符串
    return tuple(int(part) if part.isdigit() else part for part in parts if part)


# 从文件名中提取包信息
def parse_package_filename(filename):
    # 定义一个更通用的正则表达式模式
    pattern = re.compile(
        r"^(?P<package_name>)?"
        r"(?:(?P<debug>-debug))?"
        r"(?:(?P<epoch>\d+):)?"
        r"(?P<version>"
        r"(?:(?:\d+[\._-])*(?:\d+|alpha|beta|rc|post)[\._-]*)?"  # 基本版本号
        r"(?:r\d+)?(?:-g[0-9a-f]+)?"  # r 和 g 标签
        r"|"
        r"\d{8}_[0-9a-f]+"  # 特殊日期格式版本号
        r")"
        r"-(?P<build_number>\d+)"
        r"-(?P<architecture>.+?)\.pkg\.tar\.zst$"
    )

    match = pattern.match(filename)
    if match:
        package_name = match.group("package_name")
        debug = match.group("debug") or ""
        epoch = match.group("epoch") or ""  # epoch 可以为空
        version = match.group("version")
        build_number = match.group("build_number")
        architecture = match.group("architecture")
        full_version = f"{epoch}:{version}" if epoch else version
        return (package_name, full_version, build_number, architecture, debug)
    else:
        raise ValueError(
            f"Unable to parse version information from filename: {filename}"
        )


# 主逻辑
def main():
    # 打开日志文件以追加模式写入
    with open(LOG_PATH, "a") as log_file:
        log_file.write(f"Cleanup started at {datetime.now()}\n")

        # 遍历所有架构目录
        for arch in ["aarch64", "any", "riscv64", "x86_64"]:
            arch_dir = os.path.join(REPO_PATH, arch)

            if not os.path.exists(arch_dir):
                log_file.write(f"Directory {arch_dir} does not exist. Skipping.\n")
                continue

            # 收集所有 .pkg.tar.zst 文件
            all_files = [f for f in os.listdir(arch_dir) if f.endswith(".pkg.tar.zst")]

            # 创建一个字典来存储每个包的版本
            packages = defaultdict(list)
            for package_file in all_files:
                try:
                    (package_name, full_version, build_number, architecture, debug) = (
                        parse_package_filename(package_file)
                    )
                    key = (package_name, full_version, debug)
                    packages[key].append((full_version, build_number, package_file))
                except ValueError as e:
                    log_file.write(f"Error processing file {package_file}: {e}\n")

            # 对每个包的版本进行排序并决定哪些版本需要保留
            for (package_name, version, debug), files in packages.items():
                if len(files) < KEEP_VERSIONS:
                    log_file.write(
                        f"Less than {KEEP_VERSIONS} versions of {package_name} found. Skipping.\n"
                    )
                    continue

                # 根据版本信息和编译次数进行排序
                files.sort(key=lambda x: (parse_version(x[0]), int(x[1])), reverse=True)

                # 保留最新的两个版本
                versions_to_keep = [f[2] for f in files[:KEEP_VERSIONS]]  # 只保留文件名

                # 删除多余的版本
                for file_info in files[KEEP_VERSIONS:]:
                    file = file_info[2]  # 获取文件名
                    delete_path = os.path.join(arch_dir, file)
                    if DELETE:
                        os.remove(delete_path)
                        sig_file = delete_path + ".sig"
                        if os.path.exists(sig_file):
                            os.remove(sig_file)
                            log_file.write(f"Deleted: {file} and {file}.sig\n")
                        else:
                            log_file.write(f"Deleted: {file}\n")
                    else:
                        log_file.write(f"To be deleted: {file}\n")

        log_file.write(f"Cleanup completed at {datetime.now()}\n")


if __name__ == "__main__":
    main()
