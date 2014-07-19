#!/bin/bash
if ! [ -e "$HOME/.rvm" ]; then
	\curl -sSL https://get.rvm.io | bash -s stable
	source "$HOME/.rvm/scripts/rvm"
fi

rvm install ruby-2.1
#rvm 2.1 do rvm-exec gemset create raidopt
rvm ruby-2.1.2 do rvm gemset create raidopt
rvm-exec 2.1@raidopt gem install nokogiri -v 1.5.5
rvm-exec 2.1@raidopt gem install rbvmomi
rvm-exec 2.1@raidopt gem install highline
rvm-exec 2.1@raidopt gem install simple-xml
