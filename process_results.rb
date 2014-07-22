require 'rubygems'
require 'xmlsimple'

raise "Invalid args: file 8|4x830|4x840 0|5|6|10|50|60 64|128|256|512|1024 normal|ahead write-back|write-thru cached|direct" unless ARGV.size == 7
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
      out_csv.print("disks,raid,strip size,read policy,write policy,io policy,benchmark,value\n")
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
