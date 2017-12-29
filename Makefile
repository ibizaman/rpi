.PHONY: help install-archlinux format fileserver


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
