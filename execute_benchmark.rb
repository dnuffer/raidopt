require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'

if ARGV.size != 68
  STDERR.puts "Invalid args: template 1-8 0|1|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct swap-size disk-size memory-size num-cpus scheduler block-size ext4-stride ext4-stripe-width ext4-journal-mode ext4-barrier ext4-atime ext4-diratime ext4-64-bit ext4-dir-index ext4-dir-nlink, ext4-extent ext4-extra-isize ext-ext-attr ext4-filetype ext4-flex-bg ext4-flex-bg-num-groups ext4-huge-file ext4-sparse-super2 ext4-mmp ext4-resize-inode ext4-sparse-super ext4-uninit-bg ext4-inode-size ext4-inode-ratio ext4-num-backup-sb ext4-packed-meta-blocks ext4-acl ext4-inode-allocator ext4-user-xattr ext4-journal-commit-interval ext4-journal-checksum-async-commit ext4-delalloc ext4-max-batch-time ext4-min-batch-time ext4-journal-ioprio ext4-auto-da-alloc ext4-discard ext4-dioread-lock ext4-i-version kernel-vm-dirty-ratio kernel-vm-dirty-background-ratio kernel-vm-swappiness kernel-read-ahead kernel-fs-read-ahead kernel-dev-ncq ext4-bh kernel-vm-vfs-cache-pressure kernel-vm-dirty-expire-centisecs kernel-vm-dirty-writeback-centisecs kernel-vm-extfrag-threshold kernel-vm-hugepages-treat-as-movable kernel-vm-laptop-mode kernel-vm-overcommit-memory kernel-vm-overcommit-ratio kernel-vm-percpu-pagelist-fraction kernel-vm-zone-reclaim-mode"
  exit 100
end

template = ARGV.shift
raid_disks = ARGV.shift
raid_level = ARGV.shift
raid_strip_size = ARGV.shift
raid_read_ahead = ARGV.shift
raid_write_cache = ARGV.shift
raid_read_cache = ARGV.shift
swap_size = ARGV.shift.to_f
disk_size = ARGV.shift.to_f
memory_size = ARGV.shift.to_i
num_cpus = ARGV.shift.to_i
scheduler = ARGV.shift
ext4_block_size = ARGV.shift
ext4_stride = ARGV.shift
ext4_stripe_width = ARGV.shift
ext4_journal_mode = ARGV.shift
ext4_barrier = ARGV.shift
ext4_atime = ARGV.shift
ext4_diratime = ARGV.shift
ext4_64bit = ARGV.shift
ext4_dir_index = ARGV.shift
ext4_dir_nlink = ARGV.shift
ext4_extent = ARGV.shift
ext4_extra_isize = ARGV.shift
ext4_ext_attr = ARGV.shift
ext4_filetype = ARGV.shift
ext4_flex_bg = ARGV.shift
ext4_flex_bg_num_groups = ARGV.shift
ext4_huge_file = ARGV.shift
ext4_sparse_super2 = ARGV.shift
ext4_mmp = ARGV.shift
ext4_resize_inode = ARGV.shift
ext4_sparse_super = ARGV.shift
ext4_uninit_bg = ARGV.shift
ext4_inode_size = ARGV.shift
ext4_inode_ratio = ARGV.shift
ext4_num_backup_sb = ARGV.shift
ext4_packed_meta_blocks = ARGV.shift
ext4_acl = ARGV.shift
ext4_inode_allocator = ARGV.shift
ext4_user_xattr = ARGV.shift
ext4_journal_commit_interval = ARGV.shift
ext4_journal_checksum_async_commit = ARGV.shift
#ext4_inode_readahead = ARGV.shift
ext4_delalloc = ARGV.shift
ext4_max_batch_time = ARGV.shift
ext4_min_batch_time = ARGV.shift
ext4_journal_ioprio = ARGV.shift
ext4_auto_da_alloc = ARGV.shift
ext4_discard = ARGV.shift
ext4_dioread_lock = ARGV.shift
ext4_i_version = ARGV.shift
kernel_vm_dirty_ratio = ARGV.shift
kernel_vm_dirty_background_ratio = ARGV.shift
kernel_vm_swappiness = ARGV.shift
kernel_read_ahead = ARGV.shift
kernel_fs_read_ahead = ARGV.shift
kernel_dev_ncq = ARGV.shift
ext4_bh = ARGV.shift
kernel_vm_vfs_cache_pressure = ARGV.shift
kernel_vm_dirty_expire_centisecs = ARGV.shift
kernel_vm_dirty_writeback_centisecs = ARGV.shift
kernel_vm_extfrag_threshold = ARGV.shift
kernel_vm_hugepages_treat_as_movable = ARGV.shift
kernel_vm_laptop_mode = ARGV.shift
kernel_vm_overcommit_memory = ARGV.shift
kernel_vm_overcommit_ratio = ARGV.shift
kernel_vm_percpu_pagelist_fraction = ARGV.shift
kernel_vm_zone_reclaim_mode = ARGV.shift

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
  puts "Resizing swap disk to #{swap_size} GiB"
  resize_disk(vm, swap_size * 1024 * 1024 * 1024, 0, 1)
end

puts "Resizing test disk to #{disk_size} GiB"
resize_disk(vm, disk_size * 1024 * 1024 * 1024, 0, 2)

puts "Resizing memory to #{memory_size} MiB"
resize_memory(vm, memory_size)

puts "Changing number of cpus to #{num_cpus}"
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

run = lambda {|cmd| run_program(vm, rootauth, "/bin/bash", "-c '#{cmd.gsub("'", "\\'")}'") }

puts "setting scheduler"
run_program(vm, rootauth, "/bin/bash", "-c 'echo #{scheduler} > /sys/block/sdc/queue/scheduler'")

# Saw that disabling swap fails given some kernel parameter settings. Try and do it first.
puts "disabling swap"
run_program(vm, rootauth, "/bin/bash", "-c 'swapoff /dev/sda5'")

if swap_size > 0
  puts "enabling test swap"
  run_program(vm, rootauth, "/bin/bash", "-c 'mkswap /dev/sdb && swapon /dev/sdb'")
end

puts "setting kernel parameters"
kernel_params = {
  "vm.dirty_ratio" => kernel_vm_dirty_ratio,
  "vm.dirty_background_ratio" => kernel_vm_dirty_background_ratio,
  "vm.swappiness" => kernel_vm_swappiness,
  "vm.vfs_cache_pressure" => kernel_vm_vfs_cache_pressure,
  "vm.dirty_expire_centisecs" => kernel_vm_dirty_expire_centisecs,
  "vm.dirty_writeback_centisecs" => kernel_vm_dirty_writeback_centisecs,
  "vm.extfrag_threshold" => kernel_vm_extfrag_threshold,
  "vm.hugepages_treat_as_movable" => kernel_vm_hugepages_treat_as_movable,
  "vm.laptop_mode" => kernel_vm_laptop_mode,
  "vm.overcommit_memory" => kernel_vm_overcommit_memory,
  "vm.overcommit_ratio" => kernel_vm_overcommit_ratio,
  "vm.percpu_pagelist_fraction" => kernel_vm_percpu_pagelist_fraction,
  "vm.zone_reclaim_mode" => kernel_vm_zone_reclaim_mode,
}

kernel_params.each do |key, value|
  run_program(vm, rootauth, "/bin/bash", "-c 'sysctl #{key}=#{value}'")
end

puts "partitioning test disk"
run_program(vm, rootauth, "/bin/bash", "-c 'echo ,,L | sfdisk /dev/sdc'")

puts "setting readahead on test disk"
run.call("blockdev --setra #{kernel_read_ahead} /dev/sdc")
run.call("blockdev --setfra #{kernel_fs_read_ahead} /dev/sdc")

puts "setting ncq on device"
run.call("echo #{kernel_dev_ncq} > /sys/block/sdc/device/queue_depth")

puts "formatting test disk"
ext4_options = [
  ext4_dir_index, 
  ext4_dir_nlink, 
  ext4_extent, 
  ext4_extra_isize, 
  ext4_ext_attr,
  ext4_filetype,
  ext4_64bit,
  ext4_flex_bg,
  ext4_huge_file,
  ext4_sparse_super2,
  ext4_mmp,
  ext4_resize_inode,
  ext4_sparse_super,
  ext4_uninit_bg
].join(",").gsub("no_", "^")

if ext4_flex_bg == "flex_bg"
  ext4_more_options = " -G #{ext4_flex_bg_num_groups} "
end

ext4_more_extended_options = ""
if ext4_sparse_super2 == "sparse_super2"
  ext4_more_extended_options += ",num_backup_sb=#{ext4_num_backup_sb}"
end

if ext4_flex_bg == "flex_bg"
  ext4_more_extended_options += ",packed_meta_blocks=#{ext4_packed_meta_blocks == "packed_meta_blocks" ? "1" : "0"}"
end

begin
  one_hour_in_secs = 1 * 60 * 60
  run_shell_capture_output(vm, rootauth, "mkfs.ext4 -b #{ext4_block_size} -O #{ext4_options} -E stride=#{ext4_stride},stripe_width=#{ext4_stripe_width}#{ext4_more_extended_options} -I #{ext4_inode_size} -i #{ext4_inode_ratio} #{ext4_more_options} /dev/sdc1", one_hour_in_secs)
rescue TimeoutException => e
  STDERR.puts "Timed out running mkfs.ext4: #{e}"
  exit 101
rescue RuntimeError => e
  STDERR.puts "Failed to run mkfs.ext4: #{e}"
  exit 102
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
mount_opts += ",#{ext4_acl}"
if ext4_inode_allocator != "unspecified"
  mount_opts += ",#{ext4_inode_allocator}"
end
mount_opts += ",#{ext4_user_xattr}"
mount_opts += ",commit=#{ext4_journal_commit_interval}"
if ext4_journal_checksum_async_commit != "no_journal_checksum"
  mount_opts += ",#{ext4_journal_checksum_async_commit}"
end
#mount_opts += ",inode_readahead=#{ext4_inode_readahead}"
mount_opts += ",#{ext4_delalloc}"
mount_opts += ",max_batch_time=#{ext4_max_batch_time}"
mount_opts += ",min_batch_time=#{ext4_min_batch_time}"
mount_opts += ",journal_ioprio=#{ext4_journal_ioprio}"
mount_opts += ",#{ext4_auto_da_alloc}"
mount_opts += ",#{ext4_discard}"
mount_opts += ",#{ext4_dioread_lock}"
if ext4_i_version == "i_version"
  mount_opts += ",#{ext4_i_version}"
end
mount_opts += ",#{ext4_bh}"

begin
  run_shell_capture_output(vm, rootauth, "mkdir /new && mount #{mount_opts} /dev/sdc1 /new && cp -a /home/dan /new && mount --bind /new /home")
rescue RuntimeError => e
  STDERR.puts "Failed: #{e}"
  exit 103
end

puts "removing previous test results"
run_program(vm, guestauth, "/bin/bash", "-c 'rm -rf /home/dan/.phoronix-test-suite/test-results/*'")

puts "running phoronix test suite"
twelve_hours_in_secs = 12 * 60 * 60
run_shell_capture_output(vm, guestauth, "cd /home/dan/phoronix-test-suite && RUN_TESTS_IN_RANDOM_ORDER=yes bash /home/dan/benchmark.sh pts/aio-stress", twelve_hours_in_secs)
puts "phoronix test suite complete"

puts "copying back results"
FileUtils.rm_f %w(benchmark-results.xml)
copy_file_from_vm(vm, guestauth, "/home/dan/.phoronix-test-suite/test-results/1/test-1.xml", "benchmark-results.xml")
puts "finished copying back results"

# TODO: TEMP DEBUG
exit

puts "Powering vm off"
vm.PowerOffVM_Task.wait_for_completion rescue nil
puts "Deleting vm"
vm.Destroy_Task.wait_for_completion
puts "VM deleted"
