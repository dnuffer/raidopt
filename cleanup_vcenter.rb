require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'
require 'pp'

def delete_array(host)
  system "ssh root@black 'cd /opt/lsi/storcli; ./storcli /c0/vall del'"

  host.configManager.storageSystem.RescanAllHba
  host.configManager.storageSystem.RescanVmfs
  host.configManager.storageSystem.RefreshStorageSystem
end

password = 'temppassword'
#password = ask("password?") {|q| q.echo = false}
$vim = VIM.connect host: 'vc', user: 'root', password: password, insecure: true
dc = $vim.serviceInstance.find_datacenter("dc1") or fail "datacenter not found"
black_host = dc.hostFolder.children.first.host.find {|host| host.name.start_with? 'black' }
raid_ds = dc.find_datastore('local-black-ssd-raid-test')
if raid_ds
  puts "found datastore #{raid_ds.name}"
  puts "shutting down and deleting vms on #{raid_ds.name}"
  raid_ds.vm.each {|vm|
    vm_name = vm.name
    puts "Found #{vm_name}, powering off"
    vm.PowerOffVM_Task.wait_for_completion rescue puts "Failed to power off #{vm_name}. Ignoring"
    puts "Deleting #{vm_name}"
    vm.Destroy_Task.wait_for_completion rescue puts "Failed to destroy #{vm_name}. Ignoring"
    puts "#{vm_name} deleted"
  }

  puts "removing datastore"
  raid_ds.host.first.key.configManager.datastoreSystem.RemoveDatastore(:datastore => raid_ds)

  puts "deleting array"
  delete_array(black_host)

end


