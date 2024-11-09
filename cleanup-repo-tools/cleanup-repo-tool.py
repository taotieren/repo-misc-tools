import os
import re
import sys
import datetime
from packaging import version

# 仓库路径
REPO_PATH = "/home/lilac/pkgs/aur-repo"
# 保留的版本数量
KEEP_VERSIONS = 2
# 日志路径
LOG_PATH = "/var/log/cleanup-repo-tool/cleanup.log"

# 确保日志目录存在
log_dir = os.path.dirname(LOG_PATH)
if not os.path.exists(log_dir):
    os.makedirs(log_dir)
    os.system(f"chown root:root {log_dir}")
    os.system(f"chmod 755 {log_dir}")

# 判断是否执行删除操作
DELETE = "-d" in sys.argv

# 打开日志文件以追加模式写入
with open(LOG_PATH, "a") as log_file:
    log_file.write(f"Cleanup started at {datetime.datetime.now()}\n")

    # 自定义版本比较函数
    def compare_versions(v1, v2):
        # 提取版本信息和编译版本
        v1_parts = v1.split("-")
        v2_parts = v2.split("-")

        v1_info = v1_parts[-2]
        v1_build = v1_parts[-1].replace(".pkg.tar.zst", "")

        v2_info = v2_parts[-2]
        v2_build = v2_parts[-1].replace(".pkg.tar.zst", "")

        # 比较版本信息
        info_cmp = version.parse(v1_info).compare(version.parse(v2_info))
        if info_cmp != 0:
            return info_cmp

        # 版本信息相同，比较编译版本
        return version.parse(v1_build).compare(version.parse(v2_build))

    # 遍历所有架构目录
    for arch in ["aarch64", "any", "riscv64", "x86_64"]:
        arch_dir = os.path.join(REPO_PATH, arch)

        # 遍历该架构目录下的所有包
        for package_file in os.listdir(arch_dir):
            if not package_file.endswith(".pkg.tar.zst"):
                continue

            # 提取包名
            package_name = re.match(r"^(.+?)-[0-9]", package_file).group(1)

            # 获取该包的所有版本
            versions = [
                f for f in os.listdir(arch_dir) if f.startswith(package_name + "-")
            ]

            # 根据自定义版本比较函数进行排序
            versions.sort(key=compare_versions, reverse=True)

            # 如果版本数量大于保留的版本数量，删除多余的版本
            if len(versions) > KEEP_VERSIONS:
                for delete_version in versions[KEEP_VERSIONS:]:
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
                                log_file.write(
                                    f"Signature file not found for {delete_version}\n"
                                )
                        else:
                            log_file.write(
                                f"To be deleted: {delete_version} and {delete_version}.sig\n"
                            )
            else:
                log_file.write(
                    f"Not enough versions of {package_name} to delete. Skipping.\n"
                )

    log_file.write(f"Cleanup completed at {datetime.datetime.now()}\n")
