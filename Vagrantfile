# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

$script = <<-SCRIPT
sudo pacman --needed --noconfirm -Sy \
     pass \
     pinentry

echo "pinentry-program pinentry" > /home/vagrant/.gnupg/gpg-agent.conf
SCRIPT


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.define "rpi" do |box|
        box.vm.box = "generic/arch"
        box.vm.box_check_update = true
        box.vm.provider :virtualbox do |vb|
            vb.gui = false
        end
        box.ssh.forward_env = [ "RPI_PASSWORD_ROOT",
                                "RPI_PASSWORD_USER",
                                "RPI_SSH_KEY",
                              ]
        #box.vm.provision "file", source: "~/.gnupg/", destination: "/home/vagrant/.gnupg"
        #box.vm.provision "shell", inline: $script
    end
    config.vm.synced_folder ".", "/vagrant"
    #config.vm.synced_folder "/tmp/rpi", "/tmp/rpi"
    #config.vm.synced_folder "~/.password-store", "/home/vagrant/.password-store"
end
