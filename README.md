```
  _____
 |  ___|__  _ __ ___ _ __ ___   __ _ _ __
 | |_ / _ \| '__/ _ \ '_ ` _ \ / _` | '_ \
 |  _| (_) | | |  __/ | | | | | (_| | | | |
 |_|__\___/|_|  \___|_| |_| |_|\__,_|_| |_|
   |  _ \(_)___  ___ _____   _____ _ __ _   _
   | | | | / __|/ __/ _ \ \ / / _ \ '__| | | |
   | |_| | \__ \ (_| (_) \ V /  __/ |  | |_| |
   |____/|_|___/\___\___/ \_/ \___|_|   \__, |
                                        |___/
```

Foreman Discovery Image
=======================

FDI is a CentOS Stream 10 bootc image for discovering hosts with Foreman.
It boots via PXE into memory, configures networking with NetworkManager and
uploads hardware facts to the Foreman Discovery plugin. It includes the
interactive discovery TUI, automatic registration, extension scripts, LLDP,
and a Smart Proxy for facts, logs, reboot and kexec provisioning.

Build the OS container with rootless Podman, then use the `image-builder` CLI
to produce a `pxe-tar-xz` archive for x86_64. This repository supports only
that bootc workflow. The runtime remains stateless; nothing is installed on
the discovered host's disks.

For deployment, follow [Building with bootc](#building-with-bootc) and
[Boot files and kernel arguments](#boot-files-and-kernel-arguments).
The [Foreman Discovery documentation](https://theforeman.org/plugins/foreman_discovery/)
describes the discovery settings and Foreman integration; its older artifact
names and ISO boot arguments must be adapted as described below.

Networking
----------

By default the instance only initializes default interface (the one it was
booted from) via DHCP. If you want to initialize all network interfaces,
provide fdi.initnet=all option on the kernel command line. Peer DNS and
routes are always acquired only from the primary interface and ignored for
secondary (PEERDNS, PEERROUTES, DEFROUTE). Network cards connected to same
networks can cause troubles due to ARP filtering.

Documentation
-------------

Discovery image has many features and configuration options. For more, visit
http://theforeman.org/plugins/foreman_discovery/

Building with bootc
-------------------

The `Containerfile` builds a CentOS Stream 10 bootable container containing the
FDI packages, scripts, TUI, facts and Smart Proxy. Build it with Podman as your
regular user; the container build does not require a VM or a running Foreman:

```sh
podman build --pull=always \
  --build-arg FDI_VERSION="$(git describe --tags --always)" \
  --build-arg FDI_RELEASE="$(date -u +%Y%m%d).1" \
  -t localhost/fdi:stream10 .
```

The package list is in `bootc/packages.txt`. The Containerfile runs
`bootc/install-packages.sh` and `bootc/configure.sh` inside the image build,
using copied scripts for compatibility with Ubuntu 24.04's Podman parser.
The build copies the existing `root/` overlay and then the bootc-specific
files in `bootc/root/`. It rebuilds
the target kernel's initramfs for live PXE boot and runs `bootc container lint`
with fatal warnings. Only the composefs check is explicitly skipped, because
this PXE squashfs workflow requires composefs to be disabled.
The build and discovered machines must support x86-64-v3, the CentOS Stream 10
CPU baseline. NICs and storage controllers must also have EL10 drivers.
Stream 9-only hardware is outside this image's supported scope. See the
[CentOS Stream 10 release notes](https://www.centos.org/centos10/).

Build arguments:

| Argument | Default | Purpose |
| --- | --- | --- |
| `BASE_IMAGE` | `quay.io/centos-bootc/centos-bootc:stream10` | Base container; a digest can pin the base input. |
| `FOREMAN_VERSION` | `nightly` | Foreman release and matching plugin repositories. |
| `FDI_VERSION` | `dev` | Value reported by the discovery version fact. |
| `FDI_RELEASE` | `1` | Value reported by the discovery release fact. |
| `FDI_ROOT_PASSWORD_HASH` | empty | Leave root locked, or set a crypt password hash and unlock root. |
| `FDI_SSH` | `0` | Set to `1` to enable SSH, including root password login, at boot. |
| `FDI_SELINUX` | `permissive` | `permissive` matches the LiveCD; `enforcing` requires validating local extensions and policy. |
| `EXTRA_PACKAGES` | empty | Space-separated additional RPM package names. |
| `EXTRA_DRIVERS` | empty | Space-separated additional kernel modules for the initramfs. |

Root is locked and SSH is disabled by default. The existing runtime options
`fdi.rootpw=...` and `fdi.ssh=1` continue to work when booting the OS. For a
**development image with root/redhat**, build with:

```sh
podman build \
  --build-arg FDI_VERSION=dev \
  --build-arg FDI_ROOT_PASSWORD_HASH="$(openssl passwd -6 redhat)" \
  --build-arg FDI_SSH=1 \
  -t localhost/fdi:dev .
```

The password hash is part of the resulting image. Use the locked default for
published images. Setting a password alone does not enable SSH.

The bootc base retains SELinux policy, the RPM database, the full distribution
kernel modules and firmware, and build tools used by Image Builder. The legacy
file-pruning steps are omitted, so image size will differ. Reboot/kexec behavior
still needs validation on the supported hardware. The package list excludes
firewalld, matching the LiveCD's effective behavior. Built-in extension files
still go under `root/opt/extension`; at boot
these are seeded into writable `/var/opt/extension`, with `/opt/extension`
remaining the public path for downloaded ZIP files and extension scripts.

### Test userspace with rootless Podman

Use `FDI_CMDLINE` to supply FDI boot options as one environment variable.
It replaces `/proc/cmdline` for FDI's Ruby code, shell scripts and service
conditions. If omitted at startup, FDI reads the real kernel command line;
an explicitly empty value hides all host boot options. It does not change the kernel,
dracut or unrelated systemd settings. No bind mount or command-line file is
needed. The container entrypoint makes the options available to services and
dispatchers even when they do not inherit its environment. Whitespace,
including newlines, separates options; use the same
`name=value` syntax as for a real boot.

A named bridge exposes an Ethernet interface that FDI can manage. Podman
assigns its address statically and provides no DHCP server, so assign matching
IP/MAC values to Podman and FDI. Choose a different subnet if this one overlaps
an existing network. Run as your regular user:

```sh
podman network create --subnet 10.89.50.0/24 --gateway 10.89.50.1 fdi-dev
fdi_cmdline='BOOTIF=01-02-00-00-00-50-10
fdi.pxip=10.89.50.10/24 fdi.pxgw=10.89.50.1 fdi.pxdns=10.89.50.1
fdi.ssh=1 fdi.rootpw=redhat'

podman run -dit --name fdi-dev --hostname fdi \
  --systemd=always --network fdi-dev --cap-add=NET_ADMIN \
  --ip 10.89.50.10 --mac-address 02:00:00:00:50:10 \
  --env FDI_CMDLINE="$fdi_cmdline" \
  -p 127.0.0.1:2222:22 \
  -p 127.0.0.1:18443:8443 -p 127.0.0.1:18448:8448 \
  localhost/fdi:stream10 /sbin/init --unit=multi-user.target
podman exec fdi-dev timeout 30s /bin/bash -c '
  until test -S /run/systemd/private; do sleep 0.1; done
  systemctl is-system-running --wait
'
```

This works with the production-default image: the runtime options enable
`root` / `redhat` and SSH inside this container. The `dev` tag works too.
`nm-prepare` creates and activates the static `primary` connection during
startup, then the Smart Proxy generates its certificate and starts. With
`BOOTIF` and no `fdi.pxip`, real PXE boots retain their DHCP behavior. Explicit
DHCP selection in the TUI still overrides boot-time static addressing.

`NET_ADMIN` is confined to the container's private network namespace. Keep the
container on its own network; FDI configures interfaces during startup. The
default pasta network uses a TAP device, which does not accept FDI's Ethernet
profile. The explicit systemd target avoids inheriting a rescue/runlevel
setting from the host environment. EL10's NFS RPC filesystem mount is skipped
inside containers because rootless Podman cannot mount it; machine boots
retain the normal NFS behavior.

To inspect the effective options and connection:

```sh
podman exec fdi-dev discovery-cmdline
podman exec fdi-dev nmcli connection show primary
podman exec fdi-dev systemctl is-active NetworkManager foreman-proxy sshd
```

Add options such as `proxy.url`, `proxy.type`, `fdi.zips`, `fdi.script` or
`fdi.pxfactname1`/`fdi.pxfactvalue1` to `fdi_cmdline` as needed. Recreate the
container to change its startup environment; `podman exec --env ...` changes
only that exec process, not the running services. `--env-file` is also usable
if its `FDI_CMDLINE=...` assignment is on a single line. As with boot arguments,
credentials in this variable are visible in container inspection output.

For a shell without dealing with console login, use:

```sh
podman exec -it fdi-dev /bin/bash -l
```

SSH provides a real password login: `ssh -p 2222 root@127.0.0.1`, password
`redhat`. The console also runs a getty: `podman attach fdi-dev`, press Enter,
and log in as `root` / `redhat`. Detach by pressing Ctrl-P, releasing it, then
Ctrl-Q. `-dit` on the run command keeps the console interactive and enables
that detach sequence.

The proxy is ready for API checks without a manual network setup script:

```sh
curl --fail http://127.0.0.1:18448/features
curl --fail http://127.0.0.1:18448/facts
curl --insecure --fail https://127.0.0.1:18443/features
podman exec fdi-dev journalctl -b -u foreman-proxy --no-pager
```

The features response should include `bmc`, `discovery_image`, `facts` and
`logs`. FDI deliberately waits for a connection called `primary` before
starting its proxy and generating its self-signed certificate.

The normal TUI unit uses `/dev/tty1`, which a Podman container does not have.
Run the same menu on an exec terminal instead:

```sh
podman exec -it --env TERM=xterm fdi-dev /bin/bash -lc discovery-menu
```

With `BOOTIF` set, the menu enters the discovery countdown and can start
registration. Press a key during the countdown for manual configuration.
To exercise the welcome/manual path, remove `BOOTIF` from `fdi_cmdline` and
use `fdi.pxmac=01-02-00-00-00-50-10` instead; networking is then configured
through the TUI, using the static values above. The existing newt UI has no
general-purpose quit action and can defer
signals while waiting for input; stop the test container from another terminal
when finished. A message about missing `/proc/fb` is expected in a container.

To reach a Foreman or Smart Proxy running on the host, resolve
`host.containers.internal` inside the container. Local Rails development setups
may reject that hostname with HTTP 403; using its numeric address avoids that
hostname check:

```sh
podman exec fdi-dev /bin/bash -c '
  host_ip=$(getent ahostsv4 host.containers.internal | awk "NR == 1 {print \$1}")
  curl -I "http://$host_ip:3000/"
  curl --fail "http://$host_ip:8000/features"
'
```

Use the corresponding URL in the TUI, with type `foreman` for port 3000 or
`proxy` for the host Smart Proxy. Registration changes Foreman state and can
trigger discovery rules. Facter can see some host hardware through sysfs even
in a container, so review the facts and use a disposable discovery test setup
before submitting them. The loopback port forwards above are intended for
local inspection; they do not establish the production callbacks to a
network-booted host.

For direct, headless registration, add
`proxy.url=http://<numeric-host-address>:3000 proxy.type=foreman` to
`FDI_CMDLINE` when creating the container. Once the proxy and networking are
active, start the normal registration service:

```sh
podman exec fdi-dev systemctl start discovery-register
podman exec fdi-dev journalctl -b -u discovery-register --no-pager
```

A successful initial upload reports HTTP 201 and creates a discovered host
in Foreman. Check that its imported `discovery_proxy_type` fact is `foreman`
and `discovery_proxy_uri` points to port 3000. To stop periodic uploads while
keeping the container available for inspection:

```sh
podman exec fdi-dev systemctl stop discovery-register
```

These checks exercise systemd, login/SSH, the TUI, NetworkManager configuration,
facts and the Smart Proxy APIs. Podman runs the host kernel and bypasses the
image's initramfs and OSTree deployment. It cannot validate PXE, the squashfs
root, Secure Boot, target-kernel drivers, BMC hardware or kexec.
`FDI_CMDLINE` emulates FDI options only; it cannot exercise dracut options
such as `root=`, `ip=` or `ostree=`.

Clean up the test container and its network:

```sh
podman rm -f fdi-dev
podman network rm fdi-dev
```

### Generate PXE artifacts with Image Builder

This is a separate step from `podman build`. The `centos-10 / pxe-tar-xz` entry
in `image-builder list` describes a package-composed image. For this container,
use `--bootc-ref` with `pxe-tar-xz` and omit `--distro`:

```sh
# Export from your rootless Podman storage.
podman save --format oci-archive --output fdi.oci localhost/fdi:stream10

# On the image-building machine, import into the storage used by the builder.
sudo skopeo copy oci-archive:fdi.oci containers-storage:localhost/fdi:stream10

sudo image-builder build pxe-tar-xz \
  --bootc-ref localhost/fdi:stream10 \
  --arch x86_64 \
  --blueprint bootc/pxe.toml \
  --output-dir output \
  --with-manifest --with-buildlog
```

The image-building machine needs `image-builder`, `osbuild`, and either
`skopeo` or `buildah`. With Buildah, replace the Skopeo import with:

```sh
fdi_image_id=$(sudo buildah pull oci-archive:fdi.oci)
sudo buildah tag "$fdi_image_id" localhost/fdi:stream10
```

The PXE build was tested with image-builder 87.0.0 and osbuild 193, using
the Buildah import. To keep output and caches on a separate filesystem,
add `--output-dir /scratch/images/fdi-stream10` (replacing `--output-dir output`),
`--cache /scratch/images/.image-builder-cache`, and
`--rpmmd-cache /scratch/images/.image-builder-rpmmd` to the build command.
Use `--output-name fdi-stream10-x86_64` to choose the artifact basename.
Older releases may lack the bootc PXE type or options shown here.
Image Builder needs mount/loop-device privileges; the `sudo` process uses a
different container store from rootless Podman. Export/import above crosses
that boundary without rebuilding the container. An image in a registry can
also be pulled into the builder's store before running the build. No ISO is
produced by `pxe-tar-xz`.

See the upstream [CLI documentation](https://osbuild.org/docs/developer-guide/projects/image-builder/usage/)
and [bootc PXE image description](https://osbuild.org/docs/user-guide/image-descriptions/bootc/pxe-tar-xz/).

### CI builds and downloads

The `Build` workflow runs for pull requests and pushes to `master`. It builds
and tests the container with rootless Podman, then passes that exact OCI image
to a separate PXE job. The PXE job runs the official Image Builder container,
pinned by digest in `.github/workflows/build.yml`, with the privileges needed
by OSBuild on an ephemeral GitHub-hosted runner. No registry publication or
Foreman instance is required.

Download artifacts from the workflow run's **Artifacts** section:

| Artifact | Contents | Retention |
| --- | --- | --- |
| `fdi-bootc-oci-pr-N`, `fdi-pxe-pr-N` | Tested container and PXE output for PR N | 15 days per run |
| `fdi-bootc-oci-master`, `fdi-pxe-master` | Container and PXE output from `master` | Up to 90 days; older image artifacts are removed after a replacement succeeds |
| `fdi-pxe-logs-pr-N`, `fdi-pxe-logs-master` | Image Builder log, manifest and build metadata, including failure diagnostics | 15 days |

The PXE artifact contains `fdi-stream10-x86_64.tar.xz`, `SHA256SUMS`,
`build-info.txt` and `validation.json`. For example, download a successful
master build by its workflow run ID and verify it:

```sh
gh run download RUN_ID --repo theforeman/foreman-discovery-image \
  --name fdi-pxe-master --dir output
(cd output && sha256sum --check SHA256SUMS)
```

Only a successful master build can prune older master image artifacts. Failed
builds preserve the previous successful output, and rerunning an older build
does not remove a newer successful image. PR artifacts and diagnostic logs
expire normally. Retention is subject to the repository/organization limit;
even the last master image expires after 90 days without a replacement.
These are temporary Actions artifacts, not permanent release assets.

CI validates archive extraction, GRUB syntax, the OSTree deployment path,
the matching EL10 kernel and required live-boot initramfs modules. It does not
boot the resulting image; BIOS/UEFI PXE and hardware validation remain
separate checks.

### Boot files and kernel arguments

The archive contains `vmlinuz`, `initrd.img`, a separate squashfs `rootfs.img`,
`grub.cfg`, an `EFI/` bootloader tree, and an upstream `README`.
Extract it into a new directory and use the files and
`grub.cfg` from that same build together. Serve the rootfs at the URL referenced
by the boot configuration, and adapt Foreman's discovery templates accordingly.
The generated `http-rootfs` entry uses `root=live:http://HTTP-SERVER/rootfs.img`;
replace that URL with the deployment's rootfs URL. Its `combined-rootfs` entry
requires an additional `combined.img`, which is not included in the archive;
the archive's `README` explains how to assemble it from the initramfs and rootfs.

The old `fdi-image/vmlinuz0`, `initrd0.img`, embedded `/fdi.iso`, and the old
`root=live:/fdi.iso rootflags=loop` arguments are specific to the LiveCD tarball.
For bootc, use the generated kernel/initramfs paths, `root=live:<rootfs URL>`,
and the exact generated `ostree=...` deployment path. Do not hard-code an
OSTree path from a previous build or mix a rootfs with another build's config.

`bootc/pxe.toml` supplies FDI's common hardware arguments. Add the deployment's
`proxy.url`, `proxy.type`, `BOOTIF`, and other `fdi.*` options to the bootloader
entry. With a rootfs fetched over the network, configure networking in the
initramfs, for example `ip=dhcp rd.neednet=1`; do not carry over the old
`rd.neednet=0` default. Static addressing/VLANs needed to download the rootfs
must also be configured using dracut's network arguments. The later FDI network
configuration cannot repair an initramfs that could not download its rootfs.

For example, append this site-specific suffix to the generated arguments
(replace the server and MAC address):

```text
ip=dhcp rd.neednet=1 BOOTIF=01-52-54-00-12-34-56 proxy.url=https://YOURPROXY:9090 proxy.type=proxy
```

Keep `BOOTIF` uppercase and include the `01-` Ethernet prefix. PXELinux can
supply it with `IPAPPEND 2`; a GRUB template can use
`BOOTIF=01-${net_default_mac}`. To register directly with Foreman instead,
use its URL and `proxy.type=foreman`. Preserve the generated live-root and
OSTree arguments as well as the hardware arguments from the blueprint.
Keep `fstab=no`: the live image must not try to mount the disk partitions
described by the intermediate bootc installation's fstab.

For development, append `fdi.ssh=1 fdi.rootpw=redhat`. Per-host discovery
options retain their existing meanings. FDI remains stateless: update and
republish the PXE files together when releasing a new container image.

### Create a UEFI USB stick from the PXE archive

PXE is the primary release artifact. A USB stick can reuse its kernel,
initramfs and squashfs without another Image Builder build. The following
manual recipe targets x86_64 UEFI with **Secure Boot disabled**. It has been
checked against the image's dracut implementation, but has not been boot-tested.
The tarball is not a disk image: do not write it directly to a USB device with
`dd` or an image writer.

Prepare a USB stick with a GPT partition table and a FAT32 EFI System Partition
large enough for the extracted files, labelled `FDIUSB`. Creating that layout
erases the selected drive; select the USB device, not an installed system disk.
Mount the partition writable by your user. This single-partition recipe
requires every file to be smaller than FAT32's 4 GiB file-size limit.

Extract the PXE archive into a working directory. Locate the kernel,
initramfs, `rootfs.img` and generated `grub.cfg` from that same archive. Set
these paths to the actual extracted files and the USB mount point:

```sh
fdi_kernel=/path/to/extracted/vmlinuz
fdi_initramfs=/path/to/extracted/initrd.img
fdi_rootfs=/path/to/extracted/rootfs.img
fdi_usb="/run/media/$USER/FDIUSB"

mkdir -p "$fdi_usb/EFI/BOOT" "$fdi_usb/boot/grub2" \
  "$fdi_usb/boot/fdi" "$fdi_usb/LiveOS"
cp "$fdi_kernel" "$fdi_usb/boot/fdi/vmlinuz"
cp "$fdi_initramfs" "$fdi_usb/boot/fdi/initramfs.img"
cp "$fdi_rootfs" "$fdi_usb/LiveOS/squashfs.img"
```

Renaming `rootfs.img` to `LiveOS/squashfs.img` supplies dracut's default
on-disk live-image layout; the file's contents stay unchanged. Create
`boot/grub2/grub.cfg` on the USB with the following entry. Replace
`REPLACE_WITH_GENERATED_DEPLOYMENT_PATH` with the exact value of `ostree=`
from the archive's generated `grub.cfg`, and retain any other required
non-network arguments from that file:

```grub
set default=0
set timeout=5
search --no-floppy --label FDIUSB --set=root

menuentry 'Foreman Discovery Image (USB)' {
    linux /boot/fdi/vmlinuz root=live:LABEL=FDIUSB rd.live.image rw rd.live.overlay.overlayfs=1 rd.live.ram=1 rd.neednet=0 rd.bootif=0 ostree=REPLACE_WITH_GENERATED_DEPLOYMENT_PATH fstab=no acpi=force nomodeset nokaslr rd.luks=0 rd.md=0 rd.dm=0 rd.lvm=0
    initrd /boot/fdi/initramfs.img
}
```

Use only one `root=` argument: replace the generated HTTP/TFTP root URL with
`root=live:LABEL=FDIUSB`. Remove `BOOTIF`, `ip=...`, `bootdev=...` and
`rd.neednet=1` from this USB entry. Without `BOOTIF`, FDI opens its manual
networking/TUI path; configure networking there before registration. Existing
`fdi.pxauto`, `fdi.pxmac`, `fdi.pxip`, `fdi.pxgw`, `fdi.pxdns`, `proxy.url` and
`proxy.type` options remain available for unattended PXE-less discovery.
For development, append `fdi.ssh=1 fdi.rootpw=redhat`.

`rd.live.ram=1` copies the squashfs into memory; allow enough RAM for that
copy and the running system. Leave the USB inserted during initial validation.
Do not configure a persistent overlay: discovery state should be discarded
on reboot. The OS can start without network access, but registration and
provisioning still need connectivity to Foreman or a Smart Proxy. Bake any
extensions needed before networking into the container.

Create a removable-media GRUB loader. On Fedora, the preparation host needs
`grub2-mkimage`, `grub2-script-check` and the `x86_64-efi` GRUB modules
(`grub2-tools` and `grub2-efi-x64-modules`). The following
runs as your regular user and writes only to the USB filesystem and a
temporary file; it does not install GRUB onto the host or modify its EFI boot
entries:

```sh
fdi_bootstrap=$(mktemp)
cat > "$fdi_bootstrap" <<'GRUB'
search --no-floppy --label FDIUSB --set=root
set prefix=($root)/boot/grub2
configfile $prefix/grub.cfg
GRUB

grub2-script-check "$fdi_usb/boot/grub2/grub.cfg"
grub2-mkimage -O x86_64-efi -p /boot/grub2 \
  -c "$fdi_bootstrap" -o "$fdi_usb/EFI/BOOT/BOOTX64.EFI" \
  part_gpt fat search search_label normal configfile linux
rm "$fdi_bootstrap"
sync
```

Unmount/eject the filesystem and choose the USB's UEFI entry in the target's
firmware boot menu. This generated loader is unsigned. Secure Boot requires
a separately validated signed shim/GRUB chain; the recipe also does not
install a legacy BIOS bootloader. A rootfs of 4 GiB or larger requires a
different layout, such as a small FAT32 ESP plus an ext4 data partition,
with GRUB search and dracut's live-root label adjusted accordingly.

After booting, verify the TUI, networking, registration, callbacks and reboot
behavior before using USB discovery for provisioning. Recreate the stick's
kernel, initramfs, squashfs and OSTree argument together for each release.
See the [dracut live-image options](https://dracut-ng.github.io/dracut/man/dracut.cmdline.7.html)
and `grub2-mkimage --help` for the underlying mechanisms.

Adding drivers/firmware
-----------------------

Install additional packages with `EXTRA_PACKAGES`, list early-boot kernel
modules in `EXTRA_DRIVERS`, and add any required repository or configuration
files to the Containerfile/overlay. The module names must exist in the image
kernel. For example, to include the distribution's Intel Ethernet modules in the
initramfs:

```sh
podman build --build-arg 'EXTRA_DRIVERS=ixgbe i40e' \
  -t localhost/fdi:stream10 .
```

Third-party modules must match the container's kernel, including signing
requirements if Secure Boot is used. Rebuild the container and regenerate
all PXE files after changing drivers.

Building a release
------------------

Build the container with explicit `FDI_VERSION` and `FDI_RELEASE`, then run
Image Builder as above. Publish the PXE archive together with its checksums,
build log and manifest; retain the container digest and package inventory
(`/usr/PACKAGES-LIST`) for troubleshooting. Update Foreman's boot files and
rootfs URL together, preferably under a directory named for the release.

The GitHub workflow builds and checks the bootc container and saves an OCI
archive. PXE artifact generation and boot tests belong on an Image Builder
worker. Existing external release jobs must be changed to use this workflow;
the old ISO/Vagrant job is no longer supported by this repository.

The default Foreman nightly repositories are mutable, and their RPMs are
unsigned. Select `FOREMAN_VERSION` for a release and pin `BASE_IMAGE` by digest
when appropriate; a base digest alone does not pin the subsequent DNF
transaction. Fully reproducible builds require repository snapshots too.

Extensions
----------

Discovery Image supports runtime extensions published via TFTP or HTTP.
Those are distributed as ZIP files with shell scripts. It is also possible
to build an image with extensions built-in which is helpful for PXE-less
environments.

To do that, [follow the
documentation](https://docs.theforeman.org/nightly/Provisioning_Hosts/index-foreman-el.html#Extending_the_Discovery_Image_provisioning)
to create directory structure in root/opt/extension folder. Do not put ZIP
files into this folder, but keep the directory structure extracted (this is
the directory where ZIP files get downloaded and extracted). Then rebuild
the image, the extensions will be started during boot.

Extensions can write under `/opt/extension`, `/etc`, `/var` and `/tmp` on the
live system. Bootc keeps `/usr` read-only: include RPMs, libraries or system
files there at container build time instead of installing them at runtime.
Writable extension data and configuration are discarded on reboot.

The `cfg_eth`, `cfg_bond` and `cfg_slave` script helpers now create
NetworkManager keyfiles under `/etc/NetworkManager/system-connections/`.
Their positional arguments and common ifcfg-style options are retained:
DHCP/static IPv4 and IPv6 addresses, prefixes/netmasks, gateways, DNS,
MAC/MTU settings, automatic connection, bond options and bond membership.
Generation works before NetworkManager starts; `reload_nm` still reloads
profiles when it is running. Unsupported settings return an error without
overwriting the existing profile. The mapping is in
`root/usr/share/fdi/ifcfg_to_keyfile.rb`.

Extensions that write `/etc/sysconfig/network-scripts/ifcfg-*` directly must
write keyfiles instead. Use native NetworkManager keyfiles for settings
outside the helper mapping. EL10 removed the ifcfg plugin; see the
[EL10 networking changes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/considerations_in_adopting_rhel_10/networking).

Additional facts
----------------

Some extra facts are reported in addition to the standard ones reported by
Facter:

```
source /etc/default/discovery
export FACTERLIB
facter | grep discovery
discovery_bootif => 52:54:00:94:9e:52
```

discovery_bootif - MAC of the interface it was booted from


Troubleshooting
---------------

The entire live root is downloaded into RAM. The old LiveCD memory minimum
no longer applies; measure the PXE artifact and its runtime memory use before
setting a minimum for deployment. Container size is not a measurement of PXE
memory requirements.

On a booted machine, tty1 runs the discovery TUI and tty2 shows the journal.
Use tty3 or higher for a login, or enable SSH. Useful log units include
`discovery-register`, `foreman-proxy`, `nm-prepare`, and `NetworkManager`.
Run `discovery-debug` to collect mounts, networking, facts and journal output.

Root and SSH are disabled by default. For development, append:

```text
fdi.ssh=1 fdi.rootpw=redhat
```

A crypt password hash is also accepted by `fdi.rootpw`; quote it for your
bootloader so dollar signs reach the kernel unchanged. For Podman use
`FDI_CMDLINE` or the build arguments above, since it does not boot the image's
kernel command line.

For early boot failures, add `rd.debug=1` and inspect the dracut emergency
shell. Verify the rootfs URL is reachable using the initramfs networking
configuration, check the published checksums, and verify the kernel, initramfs,
rootfs and generated `ostree=` path all come from the same build. Do not add
`rd.live.check`, which expects the old ISO checksum format.

Validation and limitations
--------------------------

CentOS Stream 10 rootless Podman builds and userspace smoke tests cover systemd startup,
root/redhat console and SSH login, the TUI, primary-interface configuration,
extension storage, and the HTTP/HTTPS Smart Proxy APIs. Access to a host
Foreman and Smart Proxy can be checked using the instructions above.
The environment override, service conditions and static network startup
were checked under systemd, and both registration payload formats with an
isolated HTTP receiver. Direct registration was also tested against a local
Foreman with `proxy.type=foreman`: it returned HTTP 201, created the discovered
host, and imported its static network configuration and custom test fact.
Repeated uploads and fact-cache reads were checked under Ruby 3.3 without
registration service restarts. The migrated network helpers were tested
offline and with a live bond and two member interfaces in the container's
private network namespace. TFTP ZIP extraction and extension startup were
also exercised.
Automatic provisioning was disabled for that test; Foreman callbacks into
the rootless container and kexec provisioning have not been validated.

The PXE artifact builds successfully. Archive extraction, GRUB syntax,
the OSTree deployment path in the squashfs, and inclusion of the live-root,
networking, OSTree and bootc initramfs modules were checked. It has not been
boot-tested. Before publishing a release, validate BIOS and UEFI PXE boot,
DHCP/static/VLAN/bond networking,
automatic registration and callbacks, extension download/startup, hardware
facts and LLDP, reboot and kexec provisioning, and memory use on real hosts.
Secure Boot needs its own boot-chain and kexec checks. Podman cannot establish
these guarantees. Full feature parity remains the acceptance criterion.

`pxe-tar-xz` provides network boot files, not a standalone CD/USB ISO. The
[USB recipe](#create-a-uefi-usb-stick-from-the-pxe-archive) repackages those
files for local boot and retains the manual networking/TUI path; USB boot
still needs validation. Standalone CD media are outside the primary PXE
artifact workflow.
Updates consist of rebuilding and republishing the PXE artifacts; live
`bootc upgrade` and persistent on-disk installations are outside this workflow.

The Stream 10 migration uses the EL10 Foreman repositories selected by
`VERSION_ID` in the container. The missing EL9 FDI metapackages are replaced
with their explicit Smart Proxy, discovery plugin, Ruby/newt and gettext
dependencies. The overlay supplies the same FDI scripts and TUI. Ruby code
uses APIs available in Ruby 3.3, the temporary registration cache stores plain
JSON instead of YAML objects, and CI checks the EL10 password-status format.
The cache format change preserves repeated fact comparisons with Ruby 3.3's
stricter YAML loader.

CentOS Stream 10 does not support every device supported by Stream 9.
In particular, the previous `mlx4` extra-driver example cannot be used with
the EL10 distribution kernel. Check the
[EL10 hardware changes](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/considerations_in_adopting_rhel_10/hardware-enablement)
before deploying to older machines. Keep kernel, firmware and bootloader
validation separate from userspace container checks.

Contributing
------------

Please follow our [generic contributing guidelines for
Foreman](http://theforeman.org/contribute.html#SubmitPatches). Make sure
you create [an
issue](http://projects.theforeman.org/projects/discovery/issues/new) and
select "Image" Category.

vim:tw=75

License
-------

The container recipe, utility scripts and other software in this repo are
licensed under GNU GPL v2 or later. Exceptions are individually commented
in file headers.

Generated image is covered by additional licenses, refer to Fedora and
CentOS licensing information.

