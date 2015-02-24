# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "puphpet/ubuntu1404-x64"

  # mimic django's runserver
  config.vm.network :forwarded_port, host: 8000, guest: 80

  # provisioning script
  config.vm.provision :shell, path: "conf/vagrant/bootstrap.sh", privileged: false
  config.vm.provision :shell, path: "conf/vagrant/post_deploy_actions.bash", privileged: false
  config.vm.provision :shell, path: "conf/vagrant/import_it.bash", privileged: false

  # disable standard sync and sync to /home/mapit,
  # so that it's more similar to deploy
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/home/mapit", created: true

  # avoid stdin warning message, when provisioning
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
end
