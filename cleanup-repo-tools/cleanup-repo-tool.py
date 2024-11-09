import os
import re
import sys
import datetime

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
    os.makedirs(log_dir)
    os.system(f"chown root:root {log_dir}")
    os.system(f"chmod 755 {log_dir}")


# 自定义版本解析函数
def parse_version(version_str):
    # 将版本号拆分成数字和非数字部分
    parts = re.split(r"(\d+)", version_str)
    # 将数字部分转换为整数，非数字部分保持为字符串
    return tuple(int(part) if part.isdigit() else part for part in parts if part)


# 打开日志文件以追加模式写入
with open(LOG_PATH, "a") as log_file:
    log_file.write(f"Cleanup started at {datetime.datetime.now()}\n")

    # 遍历所有架构目录
    for arch in ["aarch64", "any", "riscv64", "x86_64"]:
        arch_dir = os.path.join(REPO_PATH, arch)

        if not os.path.exists(arch_dir):
            log_file.write(f"Directory {arch_dir} does not exist. Skipping.\n")
            continue

        # 遍历该架构目录下的所有包
        for package_file in os.listdir(arch_dir):
            if not package_file.endswith(".pkg.tar.zst"):
                continue

            # 提取包名、版本信息和编译次数
            # 更灵活的正则表达式，处理包含 git 和 r 版本号的情况
            match = re.match(
                r"^(.+?)-(([\d\.-]+)(-r\d+)?(-git)?(-debug)?)-(\d+)-(.+?)\.pkg\.tar\.zst$",
                package_file,
            )
            if not match:
                log_file.write(
                    f"Unable to parse version information from filename: {package_file}\n"
                )
                continue

            (
                package_name,
                full_version,
                version_info,
                _,
                _,
                _,
                build_number,
                architecture,
            ) = match.groups()

            # 获取该包的所有版本
            versions = [
                f
                for f in os.listdir(arch_dir)
                if f.startswith(package_name + "-") and f.endswith(".pkg.tar.zst")
            ]

            # 如果版本数量少于两个，则保留所有版本
            if len(versions) < KEEP_VERSIONS:
                log_file.write(
                    f"Less than {KEEP_VERSIONS} versions of {package_name} found. Skipping.\n"
                )
                continue

            # 根据版本信息和编译次数进行排序
            def version_key(filename):
                match = re.match(
                    r"^(.+?)-(([\d\.-]+)(-r\d+)?(-git)?(-debug)?)-(\d+)-(.+?)\.pkg\.tar\.zst$",
                    filename,
                )
                if not match:
                    raise ValueError(
                        f"Unable to parse version information from filename: {filename}"
                    )
                _, full_version, version_info, _, _, _, build_number, _ = match.groups()
                return (parse_version(version_info), int(build_number))

            try:
                versions.sort(key=version_key, reverse=True)
            except ValueError as e:
                log_file.write(f"Error sorting versions for {package_name}: {e}\n")
                continue

            # 保留最新的两个版本或最新的两个编译次数
            versions_to_keep = []
            current_version = None
            build_count = 0

            for v in versions:
                match = re.match(
                    r"^(.+?)-(([\d\.-]+)(-r\d+)?(-git)?(-debug)?)-(\d+)-(.+?)\.pkg\.tar\.zst$",
                    v,
                )
                if not match:
                    continue
                _, full_version, version_info, _, _, _, build_number, _ = match.groups()

                if version_info != current_version:
                    current_version = version_info
                    build_count = 0

                if build_count < KEEP_VERSIONS:
                    versions_to_keep.append(v)
                    build_count += 1

            # 删除多余的版本
            for delete_version in set(versions) - set(versions_to_keep):
                delete_path = os.path.join(arch_dir, delete_version)
                if os.path.exists(delete_path):
                    if DELETE:
                        os.remove(delete_path)
                        sig_file = delete_path + ".sig"
                        if os.path.exists(sig_file):
                            os.remove(sig_file)
                            log_file.write(
                                f"Deleted: {delete_version} and {delete_version}.sig\n"
                            )
                        else:
                            log_file.write(f"Deleted: {delete_version}\n")
                    else:
                        log_file.write(f"To be deleted: {delete_version}\n")
            else:
                log_file.write(
                    f"Not enough versions of {package_name} to delete. Skipping.\n"
                )

    log_file.write(f"Cleanup completed at {datetime.datetime.now()}\n")
