Service QA
======

__QA tools and testing resources__

Setting up your machine:

* Install Virtualbox (https://www.virtualbox.org/wiki/Downloads)
  * On Windows, install version 4.3.15+ or 4.3.12-, NOT 4.3.14
* Install Vagrant (http://www.vagrantup.com/)

Setting up your Virtualbox in a new service-qa sandbox:

* Run `vagrant up`
* Run `vargrant reload` as the Virtualbox will need to restart

Setting up a testing session:

* You will need SSH keys to access the ecomm system for the given test
  environment (currently needed to access the rudi/uniblab server)
  * Add any needed SSH keys to ssh-agent (`ssh-add ~/.ssh/<key>`)
* `vagrant ssh`
* `cd /vagrant`
  * On Windows, type `git status` and if all files are listed as
    updated, your git setting are converting text files LF to CRLF.
    This can be updated with `git config --local core.autocrlf=false`,
    although you may have to clear and repopulate your local repo.
* All top level scripts should be executable directly, use --help for
  details
* Scripts in the /script dir can be directly invoked, --help can again
  be your guide
* Environment variables scripts to control the test location can be
  found in the /config dir or use the --location argument at the
  command line
* Environment variables override config files loaded via --location
* To run rspec tests against a given location (stage/demo): 
  * `source config/LOCATION.sh`
  * `bundle exec rspec --color --format doc`

Building containers
===================

Prerequisites:
- Install `boot2docker` for OSX (https://github.com/boot2docker/boot2docker)
- `docker login quay.io` (Contact a member of
  [platform](mailto:platformsphere@modcloth.com) if you do not have an account)


Run:
- `boot2docker up` (if needed)
- `$(boot2docker shellinit)`
- `docker build -t quay.io/modcloth/service-qa:latest .`
- `docker push quay.io/modcloth/service-qa:latest`

Deploying
=========

See [sprocket-ansible](https://github.com/modcloth/sprocket-ansible)
