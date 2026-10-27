"""Inspect the actual PXE output before publishing it; this is not a boot test."""

import configparser
import hashlib
import json
from pathlib import Path
import posixpath
import re
import subprocess
import sys
import tarfile
import tempfile


archive = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="fdi-pxe-") as temporary:
    directory = Path(temporary)
    with tarfile.open(archive, "r:xz") as tar:
        tar.extractall(directory, filter="data")
    for name in ["vmlinuz", "initrd.img", "rootfs.img", "grub.cfg", "EFI/BOOT/BOOTX64.EFI"]:
        assert (directory / name).stat().st_size > 0, name

    subprocess.run(["grub2-script-check", str(directory / "grub.cfg")], check=True)
    grub = (directory / "grub.cfg").read_text()
    assert "@OSTREE@" not in grub
    boot_paths = set(re.findall(r"ostree=([^\s]+)", grub))
    assert len(boot_paths) == 1, boot_paths
    boot_path = boot_paths.pop()

    rootfs = str(directory / "rootfs.img")
    listing = subprocess.check_output(["unsquashfs", "-ll", rootfs], text=True)
    entries, links = set(), {}
    for line in listing.splitlines():
        if " squashfs-root" not in line:
            continue
        path = line.split(" squashfs-root", 1)[1]
        if " -> " in path:
            path, target = path.split(" -> ", 1)
            links[path] = target
        entries.add(path)

    def resolve(path):
        for _ in range(20):
            parts = path.split("/")[1:]
            for i in range(1, len(parts) + 1):
                prefix = "/" + "/".join(parts[:i])
                if prefix in links:
                    path = posixpath.normpath(posixpath.join(posixpath.dirname(prefix), links[prefix], *parts[i:]))
                    break
            else:
                assert path in entries, path
                return path
        raise AssertionError("OSTree symlink loop")

    deployment = resolve(boot_path)
    assert re.fullmatch(r"/ostree/deploy/default/deploy/[0-9a-f]{64}\.0", deployment), deployment

    def read_file(path):
        return subprocess.check_output(["unsquashfs", "-cat", rootfs, resolve(deployment + path).lstrip("/")])

    assert re.search(r'^VERSION_ID="?10"?$', read_file("/usr/lib/os-release").decode(), re.MULTILINE)
    assert read_file("/usr/bin/discovery-register")
    prepare = configparser.ConfigParser()
    prepare.read_string(read_file("/usr/lib/ostree/prepare-root.conf").decode())
    assert prepare["composefs"]["enabled"] == "no"

    kernels = [path.rsplit("/", 1)[-1] for path in entries
               if re.fullmatch(re.escape(deployment) + r"/usr/lib/modules/[^/]+", path)]
    assert len(kernels) == 1 and ".el10." in kernels[0], kernels
    assert read_file(f"/usr/lib/modules/{kernels[0]}/vmlinuz") == (directory / "vmlinuz").read_bytes()
    modules = subprocess.check_output(["lsinitrd", "-m", str(directory / "initrd.img")], text=True).splitlines()
    assert {"dmsquash-live", "livenet", "network-manager", "ostree", "bootc"} <= set(modules)

with archive.open("rb") as stream:
    digest = hashlib.file_digest(stream, "sha256").hexdigest()
(archive.parent / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
validation = {"sha256": digest, "kernel": kernels[0], "ostree_boot_path": boot_path,
              "resolved_deployment": deployment, "boot_tested": False}
(archive.parent / "validation.json").write_text(json.dumps(validation, indent=2) + "\n")
print("PXE archive, GRUB, OSTree deployment, kernel and initramfs checks passed")
