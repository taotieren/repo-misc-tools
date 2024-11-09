import os
import re
import shutil
import sys
import datetime

REPO_PATH = "/home/lilac/pkgs/aur-repo"
KEEP_VERSIONS = 2
LOG_PATH = "/var/log/cleanup-repo-tool/cleanup.log"
DELETE = "-d" in sys.argv

with open(LOG_PATH, "a") as log_file:
    log_file.write(f"Cleanup started at {datetime.datetime.now()}\n")

    for arch in ["aarch64", "any", "riscv64", "x86_64"]:
        arch_dir = os.path.join(REPO_PATH, arch)

        for package_file in os.listdir(arch_dir):
            if not package_file.endswith(".pkg.tar.zst"):
                continue

            package_name, version_info, build_version, architecture = re.match(
                r"^(.+)-([^-]+)-(\d+)-([^.]+)\.pkg\.tar\.zst", package_file
            ).groups()

            versions = sorted(
                [f for f in os.listdir(arch_dir) if f.startswith(package_name + "-")]
            )

            versions = sorted(versions, key=lambda x: (x[1], int(x[2])), reverse=True)

            if len(versions) > KEEP_VERSIONS:
                for delete_version in versions[KEEP_VERSIONS:]:
                    if os.path.exists(os.path.join(arch_dir, delete_version)):
                        if DELETE:
                            os.remove(os.path.join(arch_dir, delete_version))
                            sig_file = os.path.join(arch_dir, delete_version + ".sig")
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

    log_file.write("Cleanup completed.\n")
