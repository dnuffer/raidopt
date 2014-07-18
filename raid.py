import metacomm.combinatorics.all_pairs2
all_pairs = metacomm.combinatorics.all_pairs2.all_pairs2

"""
Demo of the basic functionality - just getting pairwise/n-wise combinations
"""


# sample parameters are is taken from 
# http://www.stsc.hill.af.mil/consulting/sw_testing/improvement/cst.html


parameters = [ 
    [ "8", "4x830", "4x840" ]
    , [ "0", "5", "6", "00", "10", "50", "60" ]
    , [ "64", "128", "256", "512", "1024" ]
    , [ "normal", "ahead" ]
    , [ "write-back", "write-thru" ]
    , [ "cached", "direct" ]
    #, [ "ext4", "xfs", "btrfs" ]
    #, [ "ubuntu14.04", "centos7", "debian7.5", "opensuse13.1", "fedora20" ]
    #, [ "1GB", "0GB", "128MB", "4GB" ]
    #, [ "16GB", "32GB", "64GB" ]
    #, [ "1GB", "2GB", "4GB" ]
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
      if row[1] == "50" or row[1] == "60":
        return False
  return True

pairwise = all_pairs( parameters, filter_func = is_valid_combination )

print "PAIRWISE:"
for i, v in enumerate(pairwise):
    print "%i:\t%s" % (i + 1, str(v))

pairwise = all_pairs( parameters )
with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write("disks,raid,strip size,read policy,write policy,io policy\n")
  #experiments_csv.write("disks,raid,strip size,read policy,write policy,io policy,fs,os,swap,hd,ram\n")
  for i, v in enumerate(pairwise):
    experiments_csv.write(",".join(v) + "\n")


total = 1
for p in parameters:
  total *= len(p)

print "Complete enumeration has", total, "combinations"
    
