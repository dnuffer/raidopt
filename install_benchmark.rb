require 'rubygems'
require 'rbvmomi'
require './vm_utils'

password = 'temppassword'
VIM = RbVmomi::VIM
$vim = VIM.connect host: 'vc', user: 'root', password: password, insecure: true
dc = $vim.serviceInstance.find_datacenter("dc1") or fail "datacenter not found"
cluster = dc.find_compute_resource 'cluster1'
black_host = cluster.host.find {|h| h.name == "black.home.nuffer.name" }
cluster_pool = cluster.resourcePool
guestauth = VIM::NamePasswordAuthentication(:interactiveSession => false, :username => 'dan', :password => 'password')

["Centos 6.5", "Centos 7", "Fedora 20", "Opensuse13.1", "Ubuntu 14.04"].each {|name|
  ["xfs", "btrfs", "ext4"].each {|fs|
    vm_name = "Disk test #{name} #{fs}"
    template = dc.find_vm(vm_name)
    if !template
      puts "Could not find template #{vm_name}"
      next
    else
      puts "Found template #{vm_name}"
    end

    if template.config.template
      puts "Marking template as VM"
      template.MarkAsVirtualMachine(:pool => cluster_pool, :host => black_host)
    end

    vm = dc.find_vm(vm_name)
    if vm.runtime.powerState != "poweredOn"
      puts "Powering on VM"
      vm.PowerOnVM_Task.wait_for_completion 
    end

    puts "Waiting for VMware tools"
    wait_for_tools(vm, guestauth)
    puts "VMware tools available"

    copy_file_to_vm(vm, guestauth, "benchmark.sh", "/home/dan/benchmark.sh")

    set_back_to_template = true
    if set_back_to_template
      puts "Shutting down guest"
      vm.ShutdownGuest

      while vm.runtime.powerState == "poweredOn"
        sleep(1)
      end

      puts "Marking VM as Template"
      vm.MarkAsTemplate
    end
  }
}
