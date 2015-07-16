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

The full installation and setup is described on the foreman_discovery
plugin site: https://github.com/theforeman/foreman_discovery

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
APPEND initrd=boot/fdi-image/initrd0.img rootflags=loop root=live:/fdi.iso rootfstype=auto ro rd.live.image acpi=force rd.luks=0 rd.md=0 rd.dm=0 rd.lvm=0 rd.bootif=0 rd.neednet=0 nomodeset proxy.url=http://YOURPROXY proxy.type=proxy
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

Only IPv4 is supported at the moment, IPv6 is not initialized.

Extending the image at runtime with a ZIPfile
---------------------------------------------

It's possible to provide a zip file containing extra code for the image to use.
First, create a directory structure like:

```
.
├── autostart.d
│   └── 01_zip.sh
├── bin
│   └── ntpdate
├── facts
│   └── test.rb
└── lib
    ├── libcrypto.so.1.0.0
    └── ruby
        └── test.rb
```

`autostart.d` contains scripts that will be executed in POSIX order by the
image as it starts up, before the host is registered to Foreman. `bin` is
added to PATH, you can place binaries here and use them in the autostart
scripts. `facts` is added to FACTERLIB so that custom facts may be
configured and sent to Foreman. `lib` is added to LD_LIBRARY_PATH and
`lib/ruby` is added to RUBYLIB, so that binaries in `bin` can be executed
properly.

Environment variables (PATH, LD_LIBRARY_PATH, RUBYLIB and FACTERLIB) are
appended to. If you need to specify the path to something explicitly in
your scripts, the zip contents are extracted to `/opt/extension` on the
image.

An example structure is provided in `example_zip` in this repo. You can zip
up your structure with `zip -r my_extension.zip .`

You can create multiple zip files, but be aware they will be extracted to
the same place on the discovery image, so files in later zips will overwrite
earlier ones if they have the same filename.

To inform the image of the extensions it should use, place your zip(s) on
your TFTP server along with the discovery image, and then update your
PXELinux APPEND line with `fdi.zips=<path-to-zip>,<path-to-zip>`, where the
paths are relative to the TFTP root. So if you have two zips at
$TFTP/zip1.zip and $TFTP/boot/zip2.zip, you would use
`fdi.zips=zip1.zip,boot/zip2.zip`.

You can force the server to download the zip files by appending
`fdi.zipserver=<tftp-address>`, where `<tftp-address>` is the IP address of
your TFTP server hosting the extensions.

Planned features
----------------

* Adding smart-proxy plugins to the proxy inside the image, from a zipfile ext
* Remote firmware upgrade.
* Remote OS image deployment.

Building
--------

Install the required packages:

```
$ sudo yum install livecd-tools pykickstart
```

To prepare CentOS 7 kickstart do:

```
$ ./build-livecd fdi-centos7.ks
```

To prepare Fedora 19 kickstart do:

```
$ ./build-livecd fdi-fedora19.ks
```

To build the image (make sure you have at least 1 GB free space in /tmp):

```
$ sudo ./build-livecd-root
```

Copy the resulting tarball to the TFTP boot directory:

```
$ tar xvf fdi-image-*.tar -C /var/lib/tftpboot/boot
```

And visit https://github.com/theforeman/foreman_discovery for more
information about how to configure Foreman and how to use the plugin.

The image is built in /tmp directory because in most modern distributions
this is mapped to memory. This is intentional, so make sure you have enough
RAM or you can experience some swapping. Alternatively, change the temp
directory in the scripts.

Additional facts
----------------

Some extra facts are reported in addition to the standard ones reported by
Facter:

```
FACTERLIB=/usr/share/fdi/facts/ facter | grep discovery
discovery_bootif => 52:54:00:94:9e:52
discovery_bootip => 192.168.122.51
```

discovery_bootif - MAC of the interface it was booted from
discovery_bootip - IP of the interface it was booted from

Kernel command line options
---------------------------

* proxy.url - URL to proxy (if omitted DNS SRV lookup is made)
* proxy.type=proxy/foreman - direct or via smart-proxy connection
* fdi.zips - extensions to download (see above)
* fdi.zipserver - override TFTP server reported by DHCP (see above)
* fdi.initnet=all/bootif - initialize all or pxe NICs (default) during startup
* fdi.ssh=1/0 - configure ssh daemon (see below)
* fdi.rootpw=string - configure ssh daemon password (see below)

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

You can use tty2 console (or higher) to login as well.

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
mv fdi-image-rhel_7_0-1.9.90-20141022.1.iso fdi.iso
livecd-iso-to-pxeboot fdi.iso
```

vim:tw=75
