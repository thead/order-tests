#!/bin/bash
set -x
set -e

ln -svf /vagrant/.vagrant-skel/bashrc /home/vagrant/.bashrc
ln -svf /vagrant/.vagrant-skel/profile /home/vagrant/.profile

if ! ls ~/qa-logging ; then
  mkdir ~/qa-logging
fi

if ! ls ~/.rbenv ; then
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
fi

if ! ls ~/.rbenv/plugins/ruby-build ; then
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

if ! cat ~/.ssh/config | grep "Host github.com" ; then
  echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
fi

#Activate rbenv
source ~/.profile

#Activate rbenv version
cd /vagrant

if rbenv version 2>&1 | grep 'not installed' ; then
  rbenv install
fi

#Activate rbenv version
cd /vagrant

if ! gem list | grep bundle ; then
  gem install bundler
  rbenv rehash
fi

if ! bundle check ; then
  bundle
fi
