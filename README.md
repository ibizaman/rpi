# RPI Installers

This repository contains a bunch of scripts automating the installation
of various things on a RPI. You only need to run the appropriate targets
in the provided `Makefile`.

First run `make install-archlinux` then `make format`. Finally, run one
of the other targets, depending on the purpose of the RPI.

`make format` will format the SD Card so you _will_ lose everything
that's on it. It will download the latest arch distribution while
partitioning the disks with fdisk and then use qemu to chroot into the
RPI and install a network profile for netctl.

`make fileserver` for now installs my
[`conffiles`](https://github.com/ibizaman/conffiles) and a few other
packages.

`make mount` and `make umount` are helper targets to respectively mount
and unmount the boot and root directories.

`make chroot` is a helper target to chroot into the sdcard. The boot and
root partitions will be automatically mounted and unmounted.
