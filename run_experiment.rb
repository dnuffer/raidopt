require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'
require 'pp'

if ARGV.size != 67
  STDERR.puts "Invalid args: 1-8 0|1|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct swap-size disk-size memory-size num-cpus scheduler block-size ext4-stride ext4-stripe-width ext4-journal-mode ext4-barrier ext4-atime ext4-diratime ext4-64-bit ext4-dir-index ext4-dir-nlink, ext4-extent ext4-extra-isize ext-ext-attr ext4-filetype ext4-flex-bg ext4-flex-bg-num-groups ext4-huge-file ext4-sparse-super2 ext4-mmp ext4-resize-inode ext4-sparse-super ext4-inode-size ext4-inode-ratio ext4-num-backup-sb ext4-packed-meta-blocks ext4-acl ext4-inode-allocator ext4-user-xattr ext4-journal-commit-interval ext4-journal-checksum-async-commit ext4-delalloc ext4-max-batch-time ext4-min-batch-time ext4-journal-ioprio ext4-auto-da-alloc ext4-discard ext4-dioread-lock ext4-i-version kernel-vm-dirty-ratio kernel-vm-dirty-background-ratio kernel-vm-swappiness kernel-read-ahead kernel-fs-read-ahead kernel-dev-ncq ext4-bh kernel-vm-vfs-cache-pressure kernel-vm-dirty-expire-centisecs kernel-vm-dirty-writeback-centisecs kernel-vm-extfrag-threshold kernel-vm-hugepages-treat-as-movable kernel-vm-laptop-mode kernel-vm-overcommit-memory kernel-vm-overcommit-ratio kernel-vm-percpu-pagelist-fraction kernel-vm-zone-reclaim-mode"
  exit 100
end

if ! system "ruby setup_datastore.rb #{ARGV.join(' ')}"
  # Occasionally this will fail because of some vmware problem. Try twice.
  sleep 60
  if ! system "ruby setup_datastore.rb #{ARGV.join(' ')}"
    STDERR.puts "failed to setup datastore: #{$?.exitstatus}"
    exit $?.exitstatus
  end
end

if ! system "ruby execute_benchmark.rb 'templates/Disk test Ubuntu 14.04 ext4' #{ARGV.join(' ')}"
  STDERR.puts "failed to execute benchmark: #{$?.exitstatus}"
  exit $?.exitstatus
end

if ! system "ruby process_results.rb benchmark-results.xml #{ARGV.join(' ')}"
  STDERR.puts "failed to process benchmark results: #{$?.exitstatus}"
  exit $?.exitstatus
end
