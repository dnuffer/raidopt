import metacomm.combinatorics.all_pairs2
all_pairs = metacomm.combinatorics.all_pairs2.all_pairs2

"""
Demo of the basic functionality - just getting pairwise/n-wise combinations
"""


# sample parameters are is taken from 
# http://www.stsc.hill.af.mil/consulting/sw_testing/improvement/cst.html


parameters = [ 
    [ "8", "4x830", "4x840 evo" ]
    , [ "0", "5", "6", "10", "50", "60" ]
    , [ "64 KB", "128 KB", "256 KB", "512 KB", "1024 KB" ]
    , [ "normal", "ahead" ]
    , [ "write-back", "write-thru" ]
    , [ "cached", "direct" ]
    , [ "ext4", "xfs", "btrfs" ]
    , [ "ubuntu14.04", "centos6.5", "debian7.5", "opensuse13.1", "fedora20" ]
]

pairwise = all_pairs( parameters )

print "PAIRWISE:"
for i, v in enumerate(pairwise):
    print "%i:\t%s" % (i + 1, str(v))

pairwise = all_pairs( parameters )
with open("experiments.csv", "w") as experiments_csv:
  experiments_csv.write("disks,raid,strip size,read policy,write policy,io policy,fs,os\n")
  for i, v in enumerate(pairwise):
    experiments_csv.write(",".join(v) + "\n")


total = 1
for p in parameters:
  total *= len(p)

print "Complete enumeration has", total, "combinations"
    
