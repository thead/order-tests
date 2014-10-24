FROM ruby:2.1.3
MAINTAINER ModCloth DevOps <devops@modcloth.com>

# Install Oracle and gem dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends wget unzip pkg-config libaio1 freetds-dev ssh

ENV LD_LIBRARY_PATH /usr/local/lib
ENV NLS_LANG American_America.UTF8
ENV USER root

# Add key to access demon machines
RUN mkdir -p /root/.ssh
ADD .docker/id_rsa /root/.ssh/id_rsa
ADD .docker/id_rsa.pub /root/.ssh/id_rsa.pub
RUN chmod 600 /root/.ssh/id_rsa
RUN echo "Host *.demo.modcloth.com\n\tStrictHostKeyChecking no" >> /root/.ssh/config
RUN echo "Host *.stage.modcloth.com\n\tStrictHostKeyChecking no" >> /root/.ssh/config
RUN echo "Host *.prod.modcloth.com\n\tStrictHostKeyChecking no" >> /root/.ssh/config

# Install Oracle libraries
RUN curl -L -s 'https://www.dropbox.com/s/9inip6bix7n8k6i/install_oracle_client.sh?dl=1' | sh
RUN ln -fsv /opt/oracle/instantclient/sdk /usr/local/lib/sdk

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install gems
ADD Gemfile /usr/src/app/
ADD Gemfile.lock /usr/src/app/
RUN bundle install --system --without development test

ADD . /usr/src/app

# Make logging directory
RUN mkdir -p /root/qa-logging

CMD ["./qa_order_test.rb"]
