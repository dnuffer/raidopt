import subprocess
import re

parameters = [ 
    ["disks" , [ "8", "7", "6", "5", "4", "3", "2", "1" ] ] # 0
    , [ "raid" , [ "raid0", "raid1", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ] ] # 1
    , [ "strip-size", [ "64", "128", "256", "512", "1024" ] ] # 2
    , [ "read-policy", [ "normal", "ahead" ] ] # 3
    , [ "write-policy", [ "write-back", "write-thru" ] ] # 4
    , [ "io-policy", [ "cached", "direct" ] ] # 5
    #, [ "ext4", "xfs", "btrfs" ] # fs
    #, [ "ubuntu14.04", "centos7", "debian7.5", "opensuse13.1", "fedora20" ] # OS
    , [ "swap-size", [ "0", ".125", ".5", "2", "4", "8", "16", "32", "64", "128" ] ] # 6 swap (GB)
    , [ "disk-size", [ "8", "16", "32", "64", "128", "256", "512", "1024", "2048", "3072" ] ] # 7 HD size (GB)
    , [ "memory-size", [ "1024", "2048", "3072", "4096", "8192", "16384" ] ] # 8 RAM
    , [ "num-cpus", [ "1", "2", "3", "4", "5", "6", "7", "8" ] ] # 9 CPUs
    , [ "scheduler", [ "deadline", "noop", "cfq" ] ] # 10 disk scheduler - https://wiki.archlinux.org/index.php/Solid_State_Drives#I.2FO_Scheduler
    # http://erikugel.wordpress.com/2011/04/14/the-quest-for-the-fastest-linux-filesystem/
    , [ "block-size", [ "1024", "2048", "4096" ] ] # 11 fs block size
    , [ "ext4-stride", [ "1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024" ] ] # 12 fs stride (ext4)
    , [ "ext4-stripe-width", [ "8", "16", "32", "64", "128", "256", "512", "1024" ] ] # 13 fs stripe width (ext4) "recommended" lowest is 16 because smallest stripe/largest block size = 64/4
    # sunit/swidth (xfs)
    , [ "ext4-journal-mode", [ "journal_data", "journal_data_ordered", "journal_data_writeback" ] ] # 14 journal mode
    , [ "ext4-barrier", [ "barrier", "no_barrier" ] ] # 15 barrier=0
    # partition alignment
    , [ "ext4-atime", [ "noatime", "strictatime", "relatime" ] ] # 16 noatime/strictatime/relatime
    , [ "ext4-diratime", [ "nodiratime", "diratime" ] ] # 17 nodiratime
    , [ "ext4-64-bit", [ "64bit", "no_64bit" ] ] # 18
    , [ "ext4-dir-index", [ "dir_index", "no_dir_index" ] ] # 19 directory indexing
    , [ "ext4-dir-nlink", [ "dir_nlink", "no_dir_nlink" ] ] # 20
    , [ "ext4-extent", [ "extent", "no_extent" ] ] # 21
    , [ "ext4-extra-isize", [ "extra_isize", "no_extra_isize" ] ] # 22
    , [ "ext4-ext-attr", [ "ext_attr", "no_ext_attr" ] ] # 23
    , [ "ext4-filetype", [ "filetype", "no_filetype" ] ] # 24
    , [ "ext4-flex-bg", [ "flex_bg", "no_flex_bg" ] ] # 25
    , [ "ext4-flex-bg-num-groups", [ "2", "4", "8", "16", "32", "64", "128", "256", "512" ] ] # 26 Number of groups used for flex_bg
    #, [ "has_journal", "no_has_journal" ]
    , [ "ext4-huge-file", [ "huge_file", "no_huge_file" ] ] # 27
    , [ "ext4-sparse-super2", [ "sparse_super2", "no_sparse_super2" ] ] # 28
    , [ "ext4-mmp", [ "mmp", "no_mmp" ] ] # 29
    # don't test quota, it seems to be buggy
    # , [ "quota", "no_quota" ]
    # , [ "both", "usr", "grp" ] # extended option: quota type, only applicable if quota is enabled
    , [ "ext4-resize-inode", [ "resize_inode", "no_resize_inode" ] ] # 30
    , [ "ext4-sparse-super", [ "sparse_super", "no_sparse_super" ] ] # 31
    , [ "ext4-uninit-bg", [ "uninit_bg", "no_uninit_bg" ] ] # 32
    , [ "ext4-inode-size", [ "128", "256", "512", "1024", "2048", "4096" ] ] # 33, inode_size
    , [ "ext4-inode-ratio", [ "16384", "65536", "262144", "1048576", "4194304", "16777216" ] ] # 34 inode_ratio
    , [ "ext4-num-backup-sb", [ "0", "1", "2" ] ] # 35 extended option: num_backup_sb
    , [ "ext4-packed-meta-blocks", [ "packed_meta_blocks", "no_packed_meta_blocks" ] ] # 36 extended option: packed_meta_blocks (only applicable if flex_bg option is enabled)
    , [ "ext4-acl", [ "acl", "noacl" ] ] # 37 mount option: acl
    , [ "ext4-inode-allocator", [ "oldalloc", "orlov", "unspecified" ] ] # 38
    , [ "ext4-user-xattr", [ "user_xattr", "nouser_xattr" ] ] # 39
    , [ "ext4-journal-commit-interval", [ "1", "2", "3", "5", "10", "20", "40", "80" ] ] # 40 journal commit interval
    , [ "ext4-journal-checksum-async-commit", [ "no_journal_checksum", "journal_checksum", "journal_async_commit" ] ] # 41
    #, [ "0", "4", "8", "16", "32", "64", "128", "512" ] # inode_readahead (default 32) - not functional on 14.04
    , [ "ext4-delalloc", [ "nodelalloc", "delalloc" ] ] # 42 nodealloc - http://www.phoronix.com/scan.php?page=article&item=ext4_linux35_tuning&num=1
    , [ "ext4-max-batch-time", [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] ] # 43 max_batch_time
    , [ "ext4-min-batch-time", [ "0", "1000", "1900", "3800", "7500", "15000", "30000", "60000", "120000", "240000" ] ] # 44 min_batch_time
    , [ "ext4-journal-ioprio", [ "0", "1", "2", "3", "4", "5", "6", "7" ] ] # 45 journal_ioprio
    , [ "ext4-auto-da-alloc", [ "auto_da_alloc", "noauto_da_alloc" ] ] # 46
    , [ "ext4-discard", [ "discard", "nodiscard" ] ] # 47
    , [ "ext4-dioread-lock", [ "dioread_lock", "dioread_nolock" ] ] # 48
    , [ "ext4-i-version", [ "i_version", "noi_version" ] ] # 49
    , [ "kernel-vm-dirty-ratio", [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] ] # 50 vm_dirty_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "kernel-vm-dirty-background-ratio", [ "1", "2", "3", "4", "5", "7", "10", "15", "20", "30" ] ] # 51 vm_dirty_background_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    , [ "kernel-vm-swappiness", [ "0", "1", "3", "10", "30", "50", "80", "90", "95", "99" ] ] # 52 vm_swappiness
    , [ "kernel-read-ahead", [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] ] # 53 read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "kernel-fs-read-ahead", [ "0", "8", "24", "128", "512", "2048", "8192", "32768", "65536", "131072" ] ] # 54 filesystem read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 must be a multiple of 8
    , [ "kernel-dev-ncq", [ "1", "2", "4", "8", "12", "16", "20", "24", "28", "32" ] ] # 55 ncq - https://raid.wiki.kernel.org/index.php/Performance#RAID-5 32 is max on my system
    , [ "ext4-bh", [ "bh", "nobh" ] ] # 56 http://blog.loxal.net/2008/01/tuning-ext3-for-performance-without.html
    , [ "kernel-vm-vfs-cache-pressure", [ "1", "3", "10", "33", "100", "333", "1000" ] ] # 57 vm.vfs_cache_pressure
    , [ "kernel-vm-dirty-expire-centisecs", [ "100", "300", "1000", "3000", "10000", "30000", "100000" ] ] # 58 vm.dirty_expire_centisecs (3000 default)
    , [ "kernel-vm-dirty-writeback-centisecs", [ "0", "30", "125", "250", "500", "1000", "2000", "4000", "10000", "30000", "100000" ] ] # 59 vm.dirty_writeback_centisecs (default 500, 0 disables)
    , [ "kernel-vm-extfrag-threshold", [ "-1", "0", "100", "200", "300", "400", "500", "600", "700", "800", "900", "1000" ] ] # 60 vm.extfrag_threshold
    , [ "kernel-vm-hugepages-treas-as-movable", [ "0", "1" ] ] # 61 vm.hugepages_treat_as_movable
    , [ "kernel-vm-laptop-mode", [ "0", "1", "3", "10", "33", "100", "333", "1000" ] ] # 62 vm.laptop_mode
    , [ "kernel-vm-overcommit-memory", [ "0", "1", "2" ] ] # 63 vm.overcommit_memory
    , [ "kernel-vm-overcommit-ratio", [ "32", "64", "128" ] ] # 64 vm.overcommit_ratio
    , [ "kernel-vm-percpu-pagelist-fraction", [ "0", "8", "16", "32", "64", "128" ] ] # 65 vm.percpu_pagelist_fraction
    , [ "kernel-vm-zone-reclaim-mode", [ "0", "1", "2", "3", "4", "5", "6", "7" ] ] # 66 vm.zone_reclaim_mode
]

param_dict = dict(parameters)


def cmd_line_for(param, value):
  param_idx = [x[0] for x in parameters].index(param)
  return str(param_idx + 1) + chr(ord('a') + parameters[param_idx][1].index(value))


def create_two_var_cmd_line(param1, param2, test_f):
  result = ""
  for val1 in param_dict[param1]:
    for val2 in param_dict[param2]:
      if not test_f(val1, val2):
        result += " -w" + cmd_line_for(param1, val1) + cmd_line_for(param2, val2)
  return result

def create_three_var_cmd_line(param1, param2, param3, test_f):
  result = ""
  for val1 in param_dict[param1]:
    for val2 in param_dict[param2]:
      for val3 in param_dict[param3]:
        if not test_f(val1, val2, val3):
          result += " -w" + cmd_line_for(param1, val1) + cmd_line_for(param2, val2) + cmd_line_for(param3, val3)
  return result

def create_four_var_cmd_line(param1, param2, param3, param4, test_f):
  result = ""
  for val1 in param_dict[param1]:
    for val2 in param_dict[param2]:
      for val3 in param_dict[param3]:
        for val4 in param_dict[param4]:
          if not test_f(val1, val2, val3, val4):
            result += " -w" + cmd_line_for(param1, val1) + cmd_line_for(param2, val2) + cmd_line_for(param3, val3) + cmd_line_for(param4, val4)
  return result

invalid = ""

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


invalid += create_two_var_cmd_line('disks', 'raid', is_raid_valid_combination)


def is_dioread_valid_combination(block_size, dioread):
  # EXT4-fs (sdc1): can't mount with dioread_nolock if block size != PAGE_SIZE
  if (dioread == 'dioread_nolock'):
    return block_size == '4096'
  return True

invalid += create_two_var_cmd_line('block-size', 'ext4-dioread-lock', is_dioread_valid_combination)


def is_extent_valid_combination(p64bit, extent):
  if p64bit == "64bit":
    return extent == "extent"
  return True

invalid += create_two_var_cmd_line('ext4-64-bit', 'ext4-extent', is_extent_valid_combination)

def is_inode_size_valid_combination(block_size, inode_size):
  return int(inode_size) <= int(block_size)

invalid += create_two_var_cmd_line('block-size', 'ext4-inode-size', is_inode_size_valid_combination)

def is_resize_inode_valid_combination(resize_inode, sparse_super):
  return not (resize_inode == "resize_inode" and sparse_super == "no_sparse_super")

invalid += create_two_var_cmd_line('ext4-resize-inode', 'ext4-sparse-super', is_resize_inode_valid_combination)

def is_stripe_width_valid_combination(stripe_width, stride):
  return (int(stripe_width) % int(stride)) == 0

invalid += create_two_var_cmd_line('ext4-stripe-width', 'ext4-stride', is_stripe_width_valid_combination)

def is_inode_ratio_valid_combination(block_size, inode_ratio):
  return int(block_size) < int(inode_ratio)

invalid += create_two_var_cmd_line('block-size', 'ext4-inode-ratio', is_inode_ratio_valid_combination)

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


invalid += create_four_var_cmd_line('disks', 'raid', 'swap-size', 'disk-size', is_disk_space_valid_combination)

def is_inode_ratio_and_disk_size_valid_combination(inode_ratio, disk_size):
  num_inodes = (long(disk_size) * 1024 * 1024 * 1024) / long(inode_ratio)
  return num_inodes >= 16384 and num_inodes < 2**32

invalid += create_two_var_cmd_line('ext4-inode-ratio', 'disk-size', is_inode_ratio_and_disk_size_valid_combination)

def is_meta_blocks_flex_bg_sparse_super_valid_combination(packed_meta_blocks, flex_bg, sparse_super):
  # doc for packed_meta_blocks: This option requires that the flex_bg file system feature to be enabled in order for it to have effect
  if packed_meta_blocks == "packed_meta_blocks":
    if flex_bg == "no_flex_bg":
      return False
  # This combination seems to cause a lot of issues
  return not (packed_meta_blocks == "no_packed_meta_blocks" and flex_bg == "no_flex_bg" and sparse_super == "no_uninit_bg")

invalid += create_three_var_cmd_line('ext4-packed-meta-blocks', 'ext4-flex-bg', 'ext4-sparse-super', is_meta_blocks_flex_bg_sparse_super_valid_combination)


cmd = "./jenny -n2 " + " ".join([str(len(param[1])) for param in  parameters]) + invalid
print "executing: " + cmd

output = subprocess.check_output(cmd, shell=True)

#print output
parsed = [line.strip(" ").split(" ") for line in output.split("\n")]
parsed.remove([''])
#if parsed[-1] == ['']:
parsed.pop

with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write(",".join([x[0] for x in parameters]) + "\n")
  for experiment in parsed:
    print experiment
    if experiment[0] == 'Could':
      print "!"
    else:
      experiments_csv.write(",".join([parameters[int(re.search("[0-9]+", row_item).group(0)) - 1][1][ord(re.search("[a-z]+", row_item).group(0)) - ord('a')] for row_item in experiment]) + "\n")
