require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'

raise "Invalid args: template 8|4x830|4x840 0|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct swap-size disk-size memory-size num-cpus scheduler block-size ext4-stride ext4-stripe-width ext4-journal-mode ext4-dir-index ext4-barrier ext4-atime ext4-diratime" unless ARGV.size == 20
template = ARGV[0]
swap_size = ARGV[7].to_f
disk_size = ARGV[8].to_f
memory_size = ARGV[9].to_i
num_cpus = ARGV[10].to_i
scheduler = ARGV[11]
ext4_block_size = ARGV[12]
ext4_stride = ARGV[13]
ext4_stripe_width = ARGV[14]
ext4_journal_mode = ARGV[15]
ext4_dir_index = ARGV[16]
ext4_barrier = ARGV[17]
ext4_atime = ARGV[18]
ext4_diratime = ARGV[19]

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

if swap_size > 0
  puts "Resizing swap disk"
  resize_disk(vm, swap_size * 1024 * 1024 * 1024, 0, 1)
end

puts "Resizing test disk"
resize_disk(vm, disk_size * 1024 * 1024 * 1024, 0, 2)

puts "Resizing memory"
resize_memory(vm, memory_size)

puts "Changing number of cpus"
resize_cpus(vm, num_cpus)

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

rootauth = VIM::NamePasswordAuthentication(:interactiveSession => false,
          :username => 'root', :password => 'password')

puts "Waiting for VMware tools"
wait_for_tools(vm, guestauth)
puts "VMware tools available"

puts "setting scheduler"
run_program(vm, rootauth, "/bin/bash", "-c 'echo #{scheduler} > /sys/block/sdc/queue/scheduler'")

puts "disabling swap"
run_program(vm, rootauth, "/bin/bash", "-c 'swapoff /dev/sda5'")

if swap_size > 0
  puts "enabling test swap"
  run_program(vm, rootauth, "/bin/bash", "-c 'mkswap /dev/sdb && swapon /dev/sdb'")
end

puts "partitioning test disk"
run_program(vm, rootauth, "/bin/bash", "-c 'echo ,,L | sfdisk /dev/sdc'")

puts "formatting test disk"
run_program(vm, rootauth, "/bin/bash", "-c 'mkfs.ext4 -b #{ext4_block_size} -E stride=#{ext4_stride},stripe_width=#{ext4_stripe_width} /dev/sdc1'")

puts "setting options on test disk filesystem"
run_program(vm, rootauth, "/bin/bash", "-c 'tune2fs -O has_journal -o #{ext4_journal_mode} /dev/sdc1'")
if ext4_dir_index == "dir_index"
  run_program(vm, rootauth, "/bin/bash", "-c 'tune2fs -O dir_index /dev/sdc1'")
elsif ext4_dir_index == "no_dir_index"
  run_program(vm, rootauth, "/bin/bash", "-c 'tune2fs -O ^dir_index /dev/sdc1'")
end

puts "mounting test disk"
mount_opts = "-o "
if ext4_barrier == "barrier"
  mount_opts += "barrier=1"
elsif ext4_barrier == "no_barrier"
  mount_opts += "barrier=0"
end
mount_opts += ",#{ext4_atime}"
mount_opts += ",#{ext4_diratime}"
run_program(vm, rootauth, "/bin/bash", "-c 'mkdir /new; mount #{mount_opts} /dev/sdc1 /new; cp -a /home/dan /new; mount --bind /new /home'")

puts "running phoronix test suite"
twelve_hours_in_secs = 12 * 60 * 60
run_program(vm, guestauth, "/bin/bash", "-c 'cd /home/dan/phoronix-test-suite; bash /home/dan/benchmark.sh pts/aio-stress'", twelve_hours_in_secs)
puts "phoronix test suite complete"

exit

puts "copying back results"
copy_file_from_vm(vm, guestauth, "/home/dan/.phoronix-test-suite/test-results/1/test-1.xml", "benchmark-results.xml")
puts "finished copying back results"

puts "Powering vm off"
vm.PowerOffVM_Task.wait_for_completion rescue nil
puts "Deleting vm"
vm.Destroy_Task.wait_for_completion
puts "VM deleted"
