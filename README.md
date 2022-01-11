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

This is a small redhat-based image that boots via PXE into memory,
initializes all network interfaces using NetworkManager and spawns small
script called "discovery-register" via systemd. This script determines foreman
URL either via DNS SRV or via kernel command line and uploads facts via
Foreman Discovery plugin API.

The image has foreman-proxy installed with BMC API configured to "shell"
provider. Upon request of Foreman, it reboots the node via /usr/bin/reboot
command. To initiate the restart, use the following command:

```
curl -3 -H "Accept:application/json" -H "Content-Length:0" -k -X PUT \
  http://192.168.100.100:8443/bmc/ignored/chassis/power/cycle
```

Usage
-----

This README describes bare minimum steps to PXE-boot discovery image.
The full installation and setup is described on the foreman_discovery
plugin site: http://theforeman.org/plugins/foreman_discovery/

To extract the tarball into the correct directory you can use this command:

```
wget http://downloads.theforeman.org/discovery/releases/X.X/fdi-image-X.X.X.tar \
  -O - | tar x --overwrite -C /var/lib/tftpboot/boot
```

Integrate it via the PXELinux templates in the Foreman application.

```
LABEL discovery
MENU LABEL Foreman Discovery Image
MENU DEFAULT
KERNEL boot/fdi-image/vmlinuz0
APPEND initrd=boot/fdi-image/initrd0.img rootflags=loop root=live:/fdi.iso rootfstype=auto ro rd.live.image rd.debug=1 acpi=force rd.luks=0 rd.md=0 rd.dm=0 rd.lvm=0 rd.bootif=0 rd.neednet=0 nomodeset proxy.url=http://YOURPROXY proxy.type=proxy
IPAPPEND 2
```

Make sure the APPEND statement is on *single line*.

You can also use the image standalone (without TFTP under Foreman's
control). In this case, edit your pxelinux.cfg/default file directly and
make sure the foreman.url points correctly.

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

Building
--------

FDI currently builds only against EL 8 and building in a container will NOT
work (docker/podman). The building host MUST be EL 8, other versions or Red Hat
compatible systems (e.g Fedora) WILL fail to build.

Install the required packages:

```
$ sudo dnf install lorax anaconda pykickstart
```

To prepare the kickstart do:

```
$ ./build-livecd fdi-centos8.ks
```

To build the image (this must be done on a EL 8 host):

```
$ sudo ./build-livecd-root 1.2.3 [./result] [virt]
```

The first parameter is the version of the image, the second is the target
directory and the third argument can be either virt or nonvirt. Do not build
images via the nonvirt flag as this can possibly destroy the host system - this
is intended for building inside a clean VM (see below).

When testing the image for new features or bugfixing, it is useful to enable
SSH access right away to boot the ISO directly. The first argument is version
to be recorded, the second is the destination directory and the third are
kernel command line options.

```
$ sudo ./build-livecd-root dev /var/lib/libvirt/images/ "nomodeset nokaslr fdi.ssh=1 fdi.rootpw=redhat"
```

Previously, it was possible to build with docker/podman, with lorax image
builder this is no longer possible.

To extract the kernel and initial RAM disk:

```
aux/livecd-iso-to-pxeboot fdi-XYZ.iso
```

The final step is to copy the resulting tarball to the TFTP boot directory:

```
$ tar xvf fdi-image-*.tar -C /var/lib/tftpboot/boot
```

And visit https://github.com/theforeman/foreman_discovery for more
information about how to configure Foreman and how to use the plugin.

Building a release
------------------

This chapter is for The Foreman team members, skip to the next section if
this is not for you.

To build new release, use our Jenkins CI job:

http://ci.theforeman.org/job/foreman-discovery-image-publish/

The job uses Vagrant to spin VM in OpenStack/Rackspace and then copies
the result to our downloads.theforeman.org site.

It is possible to start the job locally in libvirt:

		cd aux/vagrant-build
		LC_ALL=C repoowner=theforeman branch=master proxy_repo=3.1 vagrant up fdi-builder

Wait until the box starts up and builds the image, then connect to the box
and download the image:

		vagrant ssh-config fdi-builder | tee vagrant-ssh-config.tmp
		mkdir tmp
		scp -F vagrant-ssh-config.tmp fdi-builder:foreman-discovery-image/fdi*tar tmp/
		scp -F vagrant-ssh-config.tmp fdi-builder:foreman-discovery-image/fdi*iso tmp/

And finally (do not forget):

		LC_ALL=C repoowner=theforeman branch=master proxy_repo=3.1 vagrant destroy fdi-builder

Extensions
----------

Discovery Image supports runtime extensions published via TFTP or HTTP.
Those are distributed as ZIP files with shell scripts. It is also possible
to build an image with extensions built-in which is helpful for PXE-less
environments.

To do that, [follow the
documentation](https://theforeman.org/plugins/foreman_discovery/8.0/index.html#5.Extendingtheimage)
to create directory structure in root/opt/extension folder. Do not put ZIP
files into this folder, but keep the directory structure extracted (this is
the directory where ZIP files get downloaded and extracted). Then rebuild
the image, the extensions will be started during boot.

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

First of all make sure your server (or VM) has more than 500 MB of memory
because less memory can lead to various random kernel panic errors as the
image needs to be extracted in-place (150 MB * 2).

The first virtual console is reserved for logs, all systemd logging is
shown there. Particulary useful system logs are tagged with:

  * discovery-register - initial facts upload
  * foreman-discovery - facts refresh, reboot remote commands
  * nm-prepare - boot script which pre-configures NetworkManager
  * NetworkManager - networking information

The root account and ssh access are disabled by default, but you can enable
ssh and set root password using the following kernel command line options:

```
fdi.ssh=1 fdi.rootpw=redhat
```

Root password can also be specified in encrypted form (using 'redhat' as
an example below). Single and/or double quotes around password are
recommended to be used to prevent possible special characters
interpretation.

```
fdi.rootpw='$1$_redhat_$i3.3Eg7ko/Peu/7Q/1.wJ/'
```

You can use tty2 console (or higher) to login as well.

To debug booting issues when the system is terminated in early stage of
boot, use `systemd.confirm_spawn=true` options to interactively start one
service after another. Anothe option `rd.debug=1` option makes sure shell
will be spawned on fatal Dracut errors.

If the system is halted immediately during boot sequence, this can be
caused by corrupt image. Check the downloaded image using sha256sum. If the
problem persist, make sure rd.live.check kernel option is NOT present.
Beware that this looks like there are transmission errors of the init RAM
disk and you may have unexpected behavior. PXE is unreliable protocol,
server and TFTP must be on the same LAN.

Downstream
----------

This repostirory is downstream friendly for koji. The generated
fdi-image.ks kickstart file is self-containing. First of all, run the
initial script and provide empty base kickstart without any repositories
(they will be added via koji:

```
$ ./build-livecd fdi-empty.ks
```
Then simply build the image from kickstart called fdi-image.ks:

```
koji spin-livecd \
  fdi-image-rhel_7_0 \
  $(cat root/usr/share/fdi/VERSION) \
  --release $(cat root/usr/share/fdi/RELEASE) \
  --repo=http://my.repo/1 \
  --scratch \
  my-tag-image
  x86_64 \
  fdi-image.ks
```

Then extract the kernel and initial RAM disk:

```
aux/livecd-iso-to-pxeboot fdi-XYZ.iso
```

Contributing
------------

Please follow our (generic contributing guidelines for
Foreman)[http://theforeman.org/contribute.html#SubmitPatches]. Make sure
you create (an
issue)[http://projects.theforeman.org/projects/discovery/issues/new] and
select "Image" Category.

vim:tw=75

License
-------

The kickstart file, utility scripts and other software in this repo is
licensed under GNU GPL v2 or later. Exceptions are individually commented
in file headers.

Generated image is covered by additional licenses, refer to Fedora and
CentOS licensing information.

