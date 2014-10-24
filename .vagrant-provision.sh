#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

set -e
set -x

apt-get update -yq
apt-get install -yq \
  pkg-config \
  build-essential \
  git \
  curl \
  libmysqlclient-dev \
  libreadline-dev \
  libcurl3 \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libaio1 \
  unzip \
  mysql-client-5.5 \
  vim-nox \
  freetds-dev

if [[ ! (( -L "/usr/local/lib/libclntsh.so.11.1" &&
           -L "/usr/local/lib/libnnz11.so" &&
           -L "/usr/local/lib/libocci.so.11.1" &&
           -L "/usr/local/lib/libociei.so" &&
           -L "/usr/local/lib/libocijdbc11.so" &&
           -L "/usr/local/lib/libsqlplus.so" &&
           -L "/usr/local/lib/libsqlplusic.so" &&
           -L "/usr/local/lib/libocci.so" &&
           -L "/usr/local/lib/libclntsh.so"
           ))
   ]] ; then
  curl -L -s 'https://www.dropbox.com/s/9inip6bix7n8k6i/install_oracle_client.sh?dl=1' | sh
fi

if [[ ! (( -L "/usr/local/lib/sdk" ))
   ]] ; then
   ln -sv /opt/oracle/instantclient/sdk /usr/local/lib/sdk
fi

su - vagrant -c /vagrant/.vagrant-provision-as-vagrant.sh

echo 'Ding!'
