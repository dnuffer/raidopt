#!/bin/bash
sudo apt-get install libxml2-dev libxslt1-dev r-base

if ! [ -e "$HOME/.rvm" ]; then
	\curl -sSL https://get.rvm.io | bash -s stable
	source "$HOME/.rvm/scripts/rvm"
fi

rvm install ruby-2.1
rvm ruby-2.1.2 do rvm gemset create raidopt
rvm-exec 2.1@raidopt gem install nokogiri -v 1.5.5
rvm-exec 2.1@raidopt gem install rbvmomi
rvm-exec 2.1@raidopt gem install highline
rvm-exec 2.1@raidopt gem install xml-simple
rvm-exec 2.1@raidopt gem install pry

if ! [ -e ~/.Renviron ]; then
	echo 'R_LIBS_USER="~/.Rlibs"' > ~/.Renviron
fi

if ! [ -e ~/.Rlibs ]; then
	mkdir ~/.Rlibs
fi


install_R_package() {
	package=$1
	if ! [ -e "$HOME/.Rlibs/$package" ]; then
		R -e "install.packages(\"$package\", dependencies = TRUE, repos=\"http://cran.cnr.Berkeley.edu\", lib=\"~/.Rlibs\")"
	fi
}

install_R_package caret
install_R_package doParallel

