# RPI Installers

This repository contains a bunch of scripts automating the installation of
various things on a RPI 1 or 2.


## Prerequisites

You first need to install a few packages. Some are only available through the
AUR repository. If you already have `pacaur` installed, you can simply run `make
install-archlinux`. Otherwise check the Makefile target to know what packages to
install.


## Format SD Card

	./format.sh
    
**This will format the SD Card so you will lose everything that's on it.**

This will ask you a few questions:
* what SD card you want to format,
* what rpi model you want (1 and 2 supported),
* what network profile (in `/etc/netctl/`) you want to install.

Then it will proceed to:
* format the SD Card,
* download the latest ArchLinuxARM iso from http://os.archlinuxarm.org/os/ (in
  background while the formatting takes place),
* untar the iso to the SD Card,
* install needed packages to be able to chroot into the RPI,
* and finally chroot in the RPI and update the packages through pacman.


## fileserver/

Scripts in this folder are targeted for a file server type RPI. Unless otherwise
noted, those scripts has no dependency on each other.

### install.sh

Install various base packages like fcron, git, mdadm, python2 and 3, tmux, sudo
and vim.

Also, makes github.com a known ssh host.

Finally, enables fcron and sets and generates the =en_US.UTF-8= locale.

### aria2.sh

Installs https://github.com/ziahamza/webui-aria2 as a global systemctl service
running as user `aria2`. A random rpc-secret token is generated and inserted in
the config file at `/etc/aria2/aria2.conf`.

Also installs https://github.com/ziahamza/webui-aria2 whose web interface is
accessible on port `8888` and json-rpc server on port `6800`.

### universalmediaserver.sh

Installs http://www.universalmediaserver.com as a global systemctl service
running as user `ums`. Uses native to RPI `ffmpeb` binary.

## Miscellaneous

`./mount` and `./umount` are helper targets to respectively mount and unmount
the boot and root directories.

`./chroot` is a helper target to chroot into the sdcard. The boot and root
partitions will be automatically mounted and unmounted.
