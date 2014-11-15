import metacomm.combinatorics.all_pairs2
all_pairs = metacomm.combinatorics.all_pairs2.all_pairs2

"""
Demo of the basic functionality - just getting pairwise/n-wise combinations
"""


# sample parameters are is taken from 
# http://www.stsc.hill.af.mil/consulting/sw_testing/improvement/cst.html


parameters = [ 
    [ "8", "7", "6", "5", "4", "3", "2", "1" ]
    , [ "raid0", "raid1", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ]
    , [ "64", "128", "256", "512", "1024" ]
    , [ "normal", "ahead" ]
    , [ "write-back", "write-thru" ]
    , [ "cached", "direct" ]
    #, [ "ext4", "xfs", "btrfs" ] # fs
    #, [ "ubuntu14.04", "centos7", "debian7.5", "opensuse13.1", "fedora20" ] # OS
    , [ "0", ".125", ".5", "2", "5" ] # swap (GB)
    , [ "8", "16", "32", "64", "128", "256", "512", "1024" ] # HD size (GB)
    , [ "1024", "2048", "3072", "4096", "8192" ] # RAM
    , [ "1", "2", "3", "4", "5", "6", "7", "8" ] # CPUs
    , [ "deadline", "noop", "cfq" ] # disk scheduler - https://wiki.archlinux.org/index.php/Solid_State_Drives#I.2FO_Scheduler
    # http://erikugel.wordpress.com/2011/04/14/the-quest-for-the-fastest-linux-filesystem/
    , [ "1024", "2048", "4096" ] # fs block size
    , [ "1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024" ] # fs stride (ext4)
    , [ "8", "16", "32", "64", "128", "256", "512", "1024" ] # fs stripe width (ext4) "recommended" lowest is 16 because smallest stripe/largest block size = 64/4
    # sunit/swidth (xfs)
    , [ "journal_data", "journal_data_ordered", "journal_data_writeback" ] # journal mode
    , [ "barrier", "no_barrier" ] # barrier=0
    # partition alignment
    , [ "noatime", "strictatime", "relatime" ] # noatime/strictatime/relatime
    , [ "nodiratime", "diratime" ] # nodiratime
    , [ "64bit", "no_64bit" ]
    , [ "dir_index", "no_dir_index" ] # directory indexing
    , [ "dir_nlink", "no_dir_nlink" ]
    , [ "extent", "no_extent" ]
    , [ "extra_isize", "no_extra_isize" ]
    , [ "ext_attr", "no_ext_attr" ]
    , [ "filetype", "no_filetype" ]
    , [ "flex_bg", "no_flex_bg" ]
    , [ "2", "4", "8", "16", "32", "64", "128", "256", "512" ] # Number of groups used for flex_bg
    #, [ "has_journal", "no_has_journal" ]
    , [ "huge_file", "no_huge_file" ]
    , [ "sparse_super2", "no_sparse_super2" ]
    , [ "mmp", "no_mmp" ]
    # don't test quota, it seems to be buggy
    # , [ "quota", "no_quota" ]
    # , [ "both", "usr", "grp" ] # extended option: quota type, only applicable if quota is enabled
    , [ "resize_inode", "no_resize_inode" ]
    , [ "sparse_super", "no_sparse_super" ]
    , [ "uninit_bg", "no_uninit_bg" ]
    , [ "128", "256", "512", "1024", "2048", "4096" ] # inode_size
    , [ "1024", "4096", "16384", "65536", "262144", "1048576", "4194304", "16777216" ] # inode_ratio
    , [ "0", "1", "2" ] # extended option: num_backup_sb
    , [ "packed_meta_blocks", "no_packed_meta_blocks" ] # extended option: packed_meta_blocks (only applicable if flex_bg option is enabled)
    , [ "acl", "noacl" ] # mount option: acl
    , [ "oldalloc", "orlov", "unspecified" ]
    , [ "user_xattr", "nouser_xattr" ]
    , [ "1", "2", "3", "5", "10", "20", "40", "80" ] # journal commit interval
    , [ "no_journal_checksum", "journal_checksum", "journal_async_commit" ]
    #, [ "0", "4", "8", "16", "32", "64", "128", "512" ] # inode_readahead (default 32) - not functional on 14.04
    , [ "nodelalloc", "delalloc" ] # nodealloc - http://www.phoronix.com/scan.php?page=article&item=ext4_linux35_tuning&num=1
    , [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] # max_batch_time
    , [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] # min_batch_time
    , [ "0", "1", "2", "3", "4", "5", "6", "7" ] # journal_ioprio
    , [ "auto_da_alloc", "noauto_da_alloc" ]
    , [ "discard", "nodiscard" ]
    , [ "dioread_lock", "dioread_nolock" ]
    , [ "i_version", "noi_version" ]
    , [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] # vm_dirty_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] # vm_dirty_background_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "0", "1", "3", "10", "30", "50", "80", "90", "95", "99" ] # vm_swappiness
    , [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] # read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] # filesystem read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "1", "2", "4", "8", "12", "16", "20", "24", "28", "32" ] # ncq - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 32 is max on my system
    , [ "bh", "nobh" ] # http://blog.loxal.net/2008/01/tuning-ext3-for-performance-without.html
    , [ "1", "3", "10", "33", "100", "333", "1000" ] # vm.vfs_cache_pressure
    , [ "100", "300", "1000", "3000", "10000", "30000", "100000" ] # vm.dirty_expire_centisecs (3000 default)
    , [ "0", "30", "125", "250", "500", "1000", "2000", "4000", "10000", "30000", "100000" ] # vm.dirty_writeback_centisecs (default 500, 0 disables)
    , [ "-1", "0", "100", "200", "300", "400", "500", "600", "700", "800", "900", "1000" ] # vm.extfrag_threshold
    , [ "0", "1" ] # vm.hugepages_treat_as_movable
    , [ "0", "1", "3", "10", "33", "100", "333", "1000" ] # vm.laptop_mode
    , [ "0", "1", "2" ] # vm.overcommit_memory
    , [ "0", "1", "2", "4", "8", "16", "32", "64", "128" ] # vm.overcommit_ratio
    , [ "0", "8", "16", "32", "64", "128" ] # vm.percpu_pagelist_fraction
    , [ "0", "1", "2", "3", "4", "5", "6", "7" ] # vm.zone_reclaim_mode
]

def is_valid_combination( row ):
  """
  Should return True if combination is valid and False otherwise.

  Test row that is passed here can be incomplete.
  To prevent search for unnecessary items filtering function
  is executed with found subset of data to validate it.
  """

  n = len(row)
  if n>1:
    # check raid level compatibility with number of drives
    # [ "raid0", "raid1", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ]
    if row[1] == "raid0":
      return True
    elif row[1] == "raid1":
      return row[0] in ["2", "4", "6", "8"]
    elif row[1] == "raid5":
      return row[0] in ["3", "4", "5", "6", "7", "8"]
    elif row[1] == "raid6":
      return row[0] in ["3", "4", "5", "6", "7", "8"]
    elif row[1] == "raid00":
      return row[0] in ["2", "3", "4", "5", "6", "7", "8"]
    elif row[1] == "raid10":
      return row[0] in ["4", "8"]
    elif row[1] == "raid50":
      return row[0] in ["6", "8"]
    elif row[1] == "raid60":
      return row[0] in ["6", "8"]
    # TODO: EXT4-fs (sdc1): can't mount with dioread_nolock if block size != PAGE_SIZE
  return True

pairwise = all_pairs( parameters, filter_func = is_valid_combination )

print "PAIRWISE:"
for i, v in enumerate(pairwise):
    print "%i:\t%s" % (i + 1, str(v))

pairwise = all_pairs( parameters, filter_func = is_valid_combination )
with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write("disks,raid,strip-size,read-policy,write-policy,io-policy,swap-size,disk-size,memory-size,num-cpus,scheduler,block-size,ext4-stride,ext4-stripe-width,ext4-journal-mode,ext4-barrier,ext4-atime,ext4-diratime,ext4-64-bit,ext4-dir-index,ext4-dir-nlink,,ext4-extent,ext4-extra-isize,ext-ext-attr,ext4-filetype,ext4-flex-bg,ext4-flex-bg-num-groups,ext4-huge-file,ext4-sparse-super2,ext4-mmp,ext4-resize-inode,ext4-sparse-super,ext4-inode-size,ext4-inode-ratio,ext4-num-backup-sb,ext4-packed-meta-blocks,ext4-acl,ext4-inode-allocator,ext4-user-xattr,ext4-journal-commit-interval,ext4-journal-checksum-async-commit,ext4-delalloc,ext4-max-batch-time,ext4-min-batch-time,ext4-journal-ioprio,ext4-auto-da-alloc,ext4-discard,ext4-dioread-lock,ext4-i-version,kernel-vm-dirty-ratio,kernel-vm-dirty-background-ratio,kernel-vm-swappiness,kernel-read-ahead,kernel-fs-read-ahead,kernel-dev-ncq,ext4-bh,kernel-vm-vfs-cache-pressure,kernel-vm-dirty-expire-centisecs,kernel-vm-dirty-writeback-centisecs,kernel-vm-extfrag-threshold,kernel-vm-hugepages-treat-as-movable,kernel-vm-laptop-mode,kernel-vm-overcommit-memory,kernel-vm-overcommit-ratio,kernel-vm-percpu-pagelist-fraction,kernel-vm-zone-reclaim-mode\n")
  for i, v in enumerate(pairwise):
    experiments_csv.write(",".join(v) + "\n")


total = 1
for p in parameters:
  total *= len(p)

print "Complete enumeration has", total, "combinations"
    
