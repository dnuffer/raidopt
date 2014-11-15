require 'rubygems'
require 'rbvmomi'
require './vm_utils'
require 'highline/import'
require 'pp'

raise "Invalid args: 1-8 0|1|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct swap-size disk-size" unless ARGV.size == 8

raise "failed to setup datastore" unless system "ruby setup_datastore.rb #{ARGV.join(' ')}"
raise "failed to execute benchmark" unless system "ruby execute_benchmark.rb 'Disk test Ubuntu 14.04 ext4' #{ARGV.join(' ')}"
raise "failed to process benchmark results" unless system "ruby process_results.rb benchmark-results.xml #{ARGV.join(' ')}"
