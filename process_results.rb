require 'rubygems'
require 'xmlsimple'

raise "Invalid args: file values..." unless ARGV.size > 2
file = ARGV.shift

xml_data = open(file, "r") { |f| f.read }

data = XmlSimple.xml_in(xml_data)

require 'pp'
puts data.pretty_inspect

data["Result"].each do |result|
  benchmark_title = "#{result["Title"].first} #{result["Arguments"].first}"
  fname = "benchmark-results-all.csv"
  unless File.exist? fname
    open(fname, "a") { |out_csv|
      out_csv.print("disks,raid,strip-size,read-policy,write-policy,io-policy,swap-size,disk-size,memory-size,num-cpus,scheduler,block-size,ext4-stride,ext4-stripe-width,ext4-journal-mode,ext4-barrier,ext4-atime,ext4-diratime,ext4-64-bit,ext4-dir-index,ext4-dir-nlink,,ext4-extent,ext4-extra-isize,ext-ext-attr,ext4-filetype,ext4-flex-bg,ext4-flex-bg-num-groups,ext4-huge-file,ext4-sparse-super2,ext4-mmp,ext4-resize-inode,ext4-sparse-super,ext4-inode-size,ext4-inode-ratio,ext4-num-backup-sb,ext4-packed-meta-blocks,ext4-acl,ext4-inode-allocator,ext4-user-xattr,ext4-journal-commit-interval,ext4-journal-checksum-async-commit,ext4-delalloc,ext4-max-batch-time,ext4-min-batch-time,ext4-journal-ioprio,ext4-auto-da-alloc,ext4-discard,ext4-dioread-lock,ext4-i-version,kernel-vm-dirty-ratio,kernel-vm-dirty-background-ratio,kernel-vm-swappiness,kernel-read-ahead,kernel-fs-read-ahead,kernel-dev-ncq,ext4-bh,kernel-vm-vfs-cache-pressure,kernel-vm-dirty-expire-centisecs,kernel-vm-dirty-writeback-centisecs,kernel-vm-extfrag-threshold,kernel-vm-hugepages-treat-as-movable,kernel-vm-laptop-mode,kernel-vm-overcommit-memory,kernel-vm-overcommit-ratio,kernel-vm-percpu-pagelist-fraction,kernel-vm-zone-reclaim-mode")
      out_csv.print(",benchmark,value\n")
    }
  end
  open(fname, "a") { |out_csv|
    # want to convert lower is better into higher is better so all values are comparable.
    take_inverse = result["Proportion"].include? "LIB"
    result["Data"].each { |data|
      data["Entry"].each { |entry|
        entry["RawString"].each { |rawString|
          rawString.split(":").each { |val|
            val = 1. / val.to_f if take_inverse
            out_csv.print((ARGV + [benchmark_title, val]).join(",") + "\n")
          }
        }
      }
    }
  }
end
