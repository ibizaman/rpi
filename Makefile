.PHONY: help install-archlinux install-mac


help:  ## This help
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


# See https://wiki.archlinux.org/index.php/Raspberry_Pi#QEMU_chroot
install-archlinux:  ## Install needed packages on archlinux
	sudo pacman -Sy --noconfirm --needed \
	    curl \
	    util-linux \
	    pv \
	    arch-install-scripts \
	    dosfstools \
	    base-devel \

	mkdir -p /tmp/rpi/builds && cd /tmp/rpi/builds
	curl -L -O https://aur.archlinux.org/cgit/aur.git/snapshot/qemu-arm-static.tar.gz
	tar -xvf qemu-arm-static.tar.gz
	(cd qemu-arm-static && makepkg --needed --noconfirm -si)


install-mac:  ## Install needed packages on mac
	go get github.com/adamvduke/bcrypt-cli

	brew install \
	    findutils \
	    e2fsprogs \
	    pv

	pip3 install --upgrade pip
	pip3 install syncthingmanager

	brew install --head ./fuse-ext2.rb

	sudo cp -pR /usr/local/opt/fuse-ext2/System/Library/Filesystems/fuse-ext2.fs /Library/Filesystems/
	sudo chown -R root:wheel /Library/Filesystems/fuse-ext2.fs

	sudo cp -pR /usr/local/opt/fuse-ext2/System/Library/PreferencePanes/fuse-ext2.prefPane /Library/PreferencePanes/
	sudo chown -R root:wheel /Library/PreferencePanes/fuse-ext2.prefPane


install-mac-vagrant: install-mac  ## Install needed packages on mac for vagrant install
	brew cask install \
		virtualbox \
		virtualbox-extension-pack \
		vagrant

	vagrant plugin install vagrant-scp
