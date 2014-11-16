import subprocess
import re

parameters = [ 
    [ "8", "7", "6", "5", "4", "3", "2", "1" ] # 0
    , [ "raid0", "raid1", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ] # 1
    , [ "64", "128", "256", "512", "1024" ] # 2
    , [ "normal", "ahead" ] # 3
    , [ "write-back", "write-thru" ] # 4
    , [ "cached", "direct" ] # 5
    #, [ "ext4", "xfs", "btrfs" ] # fs
    #, [ "ubuntu14.04", "centos7", "debian7.5", "opensuse13.1", "fedora20" ] # OS
    , [ "0", ".125", ".5", "2", "4", "8", "16", "32", "64", "128" ] # 6 swap (GB)
    , [ "8", "16", "32", "64", "128", "256", "512", "1024", "2048", "3072" ] # 7 HD size (GB)
    , [ "1024", "2048", "3072", "4096", "8192", "16384" ] # 8 RAM
    , [ "1", "2", "3", "4", "5", "6", "7", "8" ] # 9 CPUs
    , [ "deadline", "noop", "cfq" ] # 10 disk scheduler - https://wiki.archlinux.org/index.php/Solid_State_Drives#I.2FO_Scheduler
    # http://erikugel.wordpress.com/2011/04/14/the-quest-for-the-fastest-linux-filesystem/
    , [ "1024", "2048", "4096" ] # 11 fs block size
    , [ "1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024" ] # 12 fs stride (ext4)
    , [ "8", "16", "32", "64", "128", "256", "512", "1024" ] # 13 fs stripe width (ext4) "recommended" lowest is 16 because smallest stripe/largest block size = 64/4
    # sunit/swidth (xfs)
    , [ "journal_data", "journal_data_ordered", "journal_data_writeback" ] # 14 journal mode
    , [ "barrier", "no_barrier" ] # 15 barrier=0
    # partition alignment
    , [ "noatime", "strictatime", "relatime" ] # 16 noatime/strictatime/relatime
    , [ "nodiratime", "diratime" ] # 17 nodiratime
    , [ "64bit", "no_64bit" ] # 18
    , [ "dir_index", "no_dir_index" ] # 19 directory indexing
    , [ "dir_nlink", "no_dir_nlink" ] # 20
    , [ "extent", "no_extent" ] # 21
    , [ "extra_isize", "no_extra_isize" ] # 22
    , [ "ext_attr", "no_ext_attr" ] # 23
    , [ "filetype", "no_filetype" ] # 24
    , [ "flex_bg", "no_flex_bg" ] # 25
    , [ "2", "4", "8", "16", "32", "64", "128", "256", "512" ] # 26 Number of groups used for flex_bg
    #, [ "has_journal", "no_has_journal" ]
    , [ "huge_file", "no_huge_file" ] # 27
    , [ "sparse_super2", "no_sparse_super2" ] # 28
    , [ "mmp", "no_mmp" ] # 29
    # don't test quota, it seems to be buggy
    # , [ "quota", "no_quota" ]
    # , [ "both", "usr", "grp" ] # extended option: quota type, only applicable if quota is enabled
    , [ "resize_inode", "no_resize_inode" ] # 30
    , [ "sparse_super", "no_sparse_super" ] # 31
    , [ "uninit_bg", "no_uninit_bg" ] # 32
    , [ "128", "256", "512", "1024", "2048", "4096" ] # 33, inode_size
    , [ "16384", "65536", "262144", "1048576", "4194304", "16777216" ] # 34 inode_ratio
    , [ "0", "1", "2" ] # 35 extended option: num_backup_sb
    , [ "packed_meta_blocks", "no_packed_meta_blocks" ] # 36 extended option: packed_meta_blocks (only applicable if flex_bg option is enabled)
    , [ "acl", "noacl" ] # 37 mount option: acl
    , [ "oldalloc", "orlov", "unspecified" ] # 38
    , [ "user_xattr", "nouser_xattr" ] # 39
    , [ "1", "2", "3", "5", "10", "20", "40", "80" ] # 40 journal commit interval
    , [ "no_journal_checksum", "journal_checksum", "journal_async_commit" ] # 41
    #, [ "0", "4", "8", "16", "32", "64", "128", "512" ] # inode_readahead (default 32) - not functional on 14.04
    , [ "nodelalloc", "delalloc" ] # 42 nodealloc - http://www.phoronix.com/scan.php?page=article&item=ext4_linux35_tuning&num=1
    , [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] # 43 max_batch_time
    , [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] # 44 min_batch_time
    , [ "0", "1", "2", "3", "4", "5", "6", "7" ] # 45 journal_ioprio
    , [ "auto_da_alloc", "noauto_da_alloc" ] # 46
    , [ "discard", "nodiscard" ] # 47
    , [ "dioread_lock", "dioread_nolock" ] # 48
    , [ "i_version", "noi_version" ] # 49
    , [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] # 50 vm_dirty_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] # 51 vm_dirty_background_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "0", "1", "3", "10", "30", "50", "80", "90", "95", "99" ] # 52 vm_swappiness
    , [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] # 53 read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] # 54 filesystem read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "1", "2", "4", "8", "12", "16", "20", "24", "28", "32" ] # 55 ncq - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 32 is max on my system
    , [ "bh", "nobh" ] # 56 http://blog.loxal.net/2008/01/tuning-ext3-for-performance-without.html
    , [ "1", "3", "10", "33", "100", "333", "1000" ] # 57 vm.vfs_cache_pressure
    , [ "100", "300", "1000", "3000", "10000", "30000", "100000" ] # 58 vm.dirty_expire_centisecs (3000 default)
    , [ "0", "30", "125", "250", "500", "1000", "2000", "4000", "10000", "30000", "100000" ] # 59 vm.dirty_writeback_centisecs (default 500, 0 disables)
    , [ "-1", "0", "100", "200", "300", "400", "500", "600", "700", "800", "900", "1000" ] # 60 vm.extfrag_threshold
    , [ "0", "1" ] # 61 vm.hugepages_treat_as_movable
    , [ "0", "1", "3", "10", "33", "100", "333", "1000" ] # 62 vm.laptop_mode
    , [ "0", "1", "2" ] # 63 vm.overcommit_memory
    , [ "0", "1", "2", "4", "8", "16", "32", "64", "128" ] # 64 vm.overcommit_ratio
    , [ "0", "8", "16", "32", "64", "128" ] # 65 vm.percpu_pagelist_fraction
    , [ "0", "1", "2", "3", "4", "5", "6", "7" ] # 66 vm.zone_reclaim_mode
]

def is_raid_valid_combination( disks, raid ):
  """
  Should return True if combination is valid and False otherwise.

  Test row that is passed here can be incomplete.
  To prevent search for unnecessary items filtering function
  is executed with found subset of data to validate it.
  """

  # check raid level compatibility with number of drives
  # [ "raid0", "raid1", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ]
  if raid == "raid0":
    return True
  elif raid == "raid1":
    return disks in ["2", "4", "6", "8"]
  elif raid == "raid5":
    return disks in ["3", "4", "5", "6", "7", "8"]
  elif raid == "raid6":
    return disks in ["3", "4", "5", "6", "7", "8"]
  elif raid == "raid00":
    return disks in ["2", "4", "6", "8"]
  elif raid == "raid10":
    return disks in ["4", "8"]
  elif raid == "raid50":
    return disks in ["6", "8"]
  elif raid == "raid60":
    return disks in ["6", "8"]
  return True

invalid = ""
for disks in parameters[0]:
  for raid in parameters[1]:
    if not is_raid_valid_combination(disks, raid):
      invalid += " -w1" + chr(ord('a') + parameters[0].index(disks)) + "2" + chr(ord('a') + parameters[1].index(raid))


def is_dioread_valid_combination(block_size, dioread):
  # EXT4-fs (sdc1): can't mount with dioread_nolock if block size != PAGE_SIZE
  if (dioread == 'dioread_nolock'):
    return block_size == '4096'
  return True

for block_size in parameters[11]:
  for dioread in parameters[48]:
    if not is_dioread_valid_combination(block_size, dioread):
      invalid += " -w12" + chr(ord('a') + parameters[11].index(block_size)) + "49" + chr(ord('a') + parameters[48].index(dioread))


def is_extent_valid_combination(p64bit, extent):
  if p64bit == "64bit":
    return extent == "extent"
  return True

for p64bit in parameters[18]:
  for extent in parameters[21]:
    if not is_extent_valid_combination(p64bit, extent):
      invalid += " -w19" + chr(ord('a') + parameters[18].index(p64bit)) + "22" + chr(ord('a') + parameters[21].index(extent))


def is_inode_size_valid_combination(block_size, inode_size):
  return int(inode_size) <= int(block_size)

for inode_size in parameters[33]:
  for block_size in parameters[11]:
    if not is_inode_size_valid_combination(block_size, inode_size):
      invalid += " -w34" + chr(ord('a') + parameters[33].index(inode_size)) + "12" + chr(ord('a') + parameters[11].index(block_size))

def is_resize_inode_valid_combination(resize_inode, sparse_super):
  return not (resize_inode == "resize_inode" and sparse_super == "no_sparse_super")

for resize_inode in parameters[30]:
  for sparse_super in parameters[31]:
    if not is_resize_inode_valid_combination(resize_inode, sparse_super):
      invalid += " -w31" + chr(ord('a') + parameters[30].index(resize_inode)) + "32" + chr(ord('a') + parameters[31].index(sparse_super))

def is_stripe_width_valid_combination(stripe_width, stride):
  return (int(stripe_width) % int(stride)) == 0

for stripe_width in parameters[13]:
  for stride in parameters[12]:
    if not is_stripe_width_valid_combination(stripe_width, stride):
      invalid += " -w14" + chr(ord('a') + parameters[13].index(stripe_width)) + "13" + chr(ord('a') + parameters[12].index(stride))

def is_inode_ratio_valid_combination(block_size, inode_ratio):
  return int(block_size) < int(inode_ratio)

for block_size in parameters[11]:
  for inode_ratio in parameters[34]:
    if not is_inode_ratio_valid_combination(block_size, inode_ratio):
      invalid += " -w12" + chr(ord('a') + parameters[11].index(block_size)) + "35" + chr(ord('a') + parameters[34].index(inode_ratio))

def is_disk_space_valid_combination(disks, raid_level, swap_size, disk_size):
  raw_size = 465.25 * float(disks)
  def raid_level_multiplier():
    if raid_level == "raid0" or raid_level == "raid00":
      return 1.0
    elif raid_level == "raid1" or raid_level == "raid10":
      return 0.5
    elif raid_level == "raid5":
      return (float(disks) - 1) / float(disks)
    elif raid_level == "raid6" or raid_level == "raid50":
      return (float(disks) - 2) / float(disks)
    elif raid_level == "raid60":
      return (float(disks) - 4) / float(disks)
  usable_size = raw_size * raid_level_multiplier()
  # 3% VMFS overhead
  usable_size *= 0.97
  return (float(swap_size) + float(disk_size)) <= usable_size

for disks in parameters[0]:
  for raid_level in parameters[1]:
    for swap_size in parameters[6]:
      for disk_size in parameters[7]:
        if not is_disk_space_valid_combination(disks, raid_level, swap_size, disk_size):
          invalid += " -w1" + chr(ord('a') + parameters[0].index(disks)) + "2" + chr(ord('a') + parameters[1].index(raid_level)) + "7" + chr(ord('a') + parameters[6].index(swap_size)) + "8" + chr(ord('a') + parameters[7].index(disk_size))

cmd = "./jenny -n2 " + " ".join([str(len(param)) for param in  parameters]) + invalid
print "executing: " + cmd

output = subprocess.check_output(cmd, shell=True)

#print output
parsed = [line.strip(" ").split(" ") for line in output.split("\n")]
parsed.remove([''])
#if parsed[-1] == ['']:
parsed.pop

with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write("disks,raid,strip-size,read-policy,write-policy,io-policy,swap-size,disk-size,memory-size,num-cpus,scheduler,block-size,ext4-stride,ext4-stripe-width,ext4-journal-mode,ext4-barrier,ext4-atime,ext4-diratime,ext4-64-bit,ext4-dir-index,ext4-dir-nlink,,ext4-extent,ext4-extra-isize,ext-ext-attr,ext4-filetype,ext4-flex-bg,ext4-flex-bg-num-groups,ext4-huge-file,ext4-sparse-super2,ext4-mmp,ext4-resize-inode,ext4-sparse-super,ext4-inode-size,ext4-inode-ratio,ext4-num-backup-sb,ext4-packed-meta-blocks,ext4-acl,ext4-inode-allocator,ext4-user-xattr,ext4-journal-commit-interval,ext4-journal-checksum-async-commit,ext4-delalloc,ext4-max-batch-time,ext4-min-batch-time,ext4-journal-ioprio,ext4-auto-da-alloc,ext4-discard,ext4-dioread-lock,ext4-i-version,kernel-vm-dirty-ratio,kernel-vm-dirty-background-ratio,kernel-vm-swappiness,kernel-read-ahead,kernel-fs-read-ahead,kernel-dev-ncq,ext4-bh,kernel-vm-vfs-cache-pressure,kernel-vm-dirty-expire-centisecs,kernel-vm-dirty-writeback-centisecs,kernel-vm-extfrag-threshold,kernel-vm-hugepages-treat-as-movable,kernel-vm-laptop-mode,kernel-vm-overcommit-memory,kernel-vm-overcommit-ratio,kernel-vm-percpu-pagelist-fraction,kernel-vm-zone-reclaim-mode\n")
  for experiment in parsed:
    print experiment
    if experiment[0] == 'Could':
      print "!"
    else:
      experiments_csv.write(",".join([parameters[int(re.search("[0-9]+", row_item).group(0)) - 1][ord(re.search("[a-z]+", row_item).group(0)) - ord('a')] for row_item in experiment]) + "\n")
