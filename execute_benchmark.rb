require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'

raise "Invalid args: template password" unless ARGV.size == 1
template = ARGV[0]

password = 'temppassword'
#password = ask("password?") {|q| q.echo = false}
$vim = VIM.connect host: 'vc', user: 'root', password: password, insecure: true
dc = $vim.serviceInstance.find_datacenter("dc1") or fail "datacenter not found"

use_existing_vm = false

# First look if the target vm already exists. if so, shut it off and delete it.
target_vm = dc.find_vm("disktest-vm")
if target_vm && !use_existing_vm
  puts "Found target, powering off"
  target_vm.PowerOffVM_Task.wait_for_completion rescue nil
  puts "Deleting target"
  target_vm.Destroy_Task.wait_for_completion
  puts "target deleted"
  target_vm = nil
end

if !target_vm
  template_vm = dc.find_vm(template) or fail "VM template #{template} not found"
  puts "Found template"

  target_datastore = dc.find_datastore("local-black-ssd-raid-test")
  fail "Couldn't find target datastore" unless target_datastore
  puts "Found target datastore"

  relocateSpec = VIM.VirtualMachineRelocateSpec(:diskMoveType => :moveAllDiskBackingsAndDisallowSharing)
  relocateSpec.transform = :flat
  relocateSpec.datastore = target_datastore
  #relocateSpec.host = opts[:host] if opts[:host]
  #relocateSpec.pool = opts[:pool] if opts[:pool]
  cluster = dc.find_compute_resource 'cluster1'
  relocateSpec.host = cluster.host.find {|h| h.name == "black.home.nuffer.name" }
  relocateSpec.pool = cluster.resourcePool
  #relocateSpec = VIM.VirtualMachineRelocateSpec(:datastore => target_datastore)
  spec = VIM.VirtualMachineCloneSpec(:location => relocateSpec,
                                    :powerOn => false,
                                    :template => false)

  puts "Starting clone of template"
  vm = template_vm.CloneVM_Task(:folder => template_vm.parent, :name => "disktest-vm", :spec => spec).
    wait_for_progress { |progress|
      puts progress
    }
  puts "Finished clone of template"
else
  vm = target_vm
end

puts "Powering on vm"
begin
  vm.PowerOnVM_Task.wait_for_completion 
rescue RbVmomi::Fault => e
  if e.fault.class.wsdl_name != "InvalidPowerState"
    raise e
  end
end
puts "VM Powered on"


guestauth = VIM::NamePasswordAuthentication(:interactiveSession => false,
          :username => 'dan', :password => 'password')

puts "Waiting for VMware tools"
wait_for_tools(vm, guestauth)
puts "VMware tools available"




puts "running phoronix test suite"
twelve_hours_in_secs = 12 * 60 * 60
run_program(vm, guestauth, "/bin/bash", "-c 'cd /home/dan/phoronix-test-suite; bash /home/dan/benchmark.sh pts/aio-stress'", twelve_hours_in_secs)
puts "phoronix test suite complete"




puts "copying back results"
copy_file_from_vm(vm, guestauth, "/home/dan/.phoronix-test-suite/test-results/1/test-1.xml", "benchmark-results.xml")
puts "finished copying back results"

puts "Powering vm off"
vm.PowerOffVM_Task.wait_for_completion rescue nil
puts "Deleting vm"
vm.Destroy_Task.wait_for_completion
puts "VM deleted"
