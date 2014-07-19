require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'
require 'pp'

raise "Invalid args: 8|4x830|4x840 0|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct" unless ARGV.size == 6

raise "failed to setup datastore" unless system "ruby setup_datastore.rb #{ARGV.join(' ')}"
raise "failed to execute benchmark" unless system "ruby execute_benchmark.rb 'Disk test Ubuntu 14.04 ext4'"
raise "failed to process benchmark results" unless system "ruby process_results.rb benchmark-results.xml #{ARGV.join(' ')}"
