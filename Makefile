.PHONY: help install-archlinux install-mac


help:  ## This help
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


# See https://wiki.archlinux.org/index.php/Raspberry_Pi#QEMU_chroot
install-archlinux:  ## Install needed packages on archlinux
	pacaur -S \
	    curl \
	    fdisk \
	    pv \
	    arch-install-scripts \
	    binfmt-support \
	    qemu-user-static


# TODO: make ext4 work without paragon
install-mac:
	brew install \
	    findutils \
	    e2fsprogs \
	    pv

	brew cask install \
	    paragon-extfs

	open /usr/local/Caskroom/paragon-extfs/latest/FSInstaller.app
