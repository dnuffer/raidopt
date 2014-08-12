import metacomm.combinatorics.all_pairs2
all_pairs = metacomm.combinatorics.all_pairs2.all_pairs2

"""
Demo of the basic functionality - just getting pairwise/n-wise combinations
"""


# sample parameters are is taken from 
# http://www.stsc.hill.af.mil/consulting/sw_testing/improvement/cst.html


parameters = [ 
    [ "8", "4x830", "4x840" ]
    , [ "raid0", "raid5", "raid6", "raid00", "raid10", "raid50", "raid60" ]
    , [ "64", "128", "256", "512", "1024" ]
    , [ "normal", "ahead" ]
    , [ "write-back", "write-thru" ]
    , [ "cached", "direct" ]
    #, [ "ext4", "xfs", "btrfs" ] # fs
    #, [ "ubuntu14.04", "centos7", "debian7.5", "opensuse13.1", "fedora20" ] # OS
    , [ "0", ".125", ".5", "2", "5" ] # swap (GB)
    , [ "8", "16", "32", "64", "128" ] # HD size (GB)
    , [ "1024", "2048", "3072", "4096" ] # RAM
    , [ "1", "2", "3", "4" ] # CPUs
    , [ "deadline", "noop", "cfq" ] # disk scheduler - https://wiki.archlinux.org/index.php/Solid_State_Drives#I.2FO_Scheduler
    # http://erikugel.wordpress.com/2011/04/14/the-quest-for-the-fastest-linux-filesystem/
    , [ "1024", "2048", "4096" ] # fs block size
    , [ "1", "2", "4", "8", "16", "32", "64", "128", "256", "512", "1024" ] # fs stride (ext4)
    , [ "8", "16", "32", "64", "128", "256", "512", "1024" ] # fs stripe width (ext4) "recommended" lowest is 16 because smallest stripe/largest block size = 64/4
    # sunit/swidth (xfs)
    , [ "journal_data", "journal_data_ordered", "journal_data_writeback" ] # journal mode
    , [ "dir_index", "no_dir_index" ] # directory indexing
    , [ "barrier", "no_barrier" ] # barrier=0
    # partition alignment
    , [ "noatime", "strictatime", "relatime" ] # noatime/strictatime/relatime
    , [ "nodiratime", "diratime" ] # nodiratime
    # nobh
    # notail
    # vm_dirty_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    # vm_dirty_background_ratio - https://wiki.archlinux.org/index.php/Sysctl#Virtual_memory
    # nodealloc - http://www.phoronix.com/scan.php?page=article&item=ext4_linux35_tuning&num=1
    # read ahead - https://raid.wiki.kernel.org/index.php/Performance#RAID-5
    # ncq - https://raid.wiki.kernel.org/index.php/Performance#RAID-5
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
    # raid 50 and 60 are not compatible with 4 drives (4x830, 4x840)
    if row[0] == "4x830" or row[0] == "4x840":
      if row[1] == "raid50" or row[1] == "raid60":
        return False
  return True

pairwise = all_pairs( parameters, filter_func = is_valid_combination )

print "PAIRWISE:"
for i, v in enumerate(pairwise):
    print "%i:\t%s" % (i + 1, str(v))

pairwise = all_pairs( parameters, filter_func = is_valid_combination )
with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write("disks,raid,strip size,read policy,write policy,io policy\n")
  #experiments_csv.write("disks,raid,strip size,read policy,write policy,io policy,fs,os,swap,hd,ram\n")
  for i, v in enumerate(pairwise):
    experiments_csv.write(",".join(v) + "\n")


total = 1
for p in parameters:
  total *= len(p)

print "Complete enumeration has", total, "combinations"
    
