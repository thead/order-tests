#!/usr/bin/env ruby

#
# Basic E-comm connection operations
#

require 'sequel'

module QAEcomm
  # An optional location object can be provided, otherwise use ENV vars or hard coded stage values
  # Can use either a readonly or read-write user depending on requirements
  def self.db_connect( location = nil, update = false )
    my_host   = location ? location.data[:SQA_ECOMM_DB_SERVER]        : ENV.fetch('SQA_ECOMM_DB_SERVER')
    my_db     = location ? location.data[:SQA_ECOMM_DB]               : ENV.fetch('SQA_ECOMM_DB')
    if update
      my_user = location ? location.data[:SQA_ECOMM_DB_UPDATE_USER]   : ENV.fetch('SQA_ECOMM_DB_UPDATE_USER')
      my_pw   = location ? location.data[:SQA_ECOMM_DB_UPDATE_PW]     : ENV.fetch('SQA_ECOMM_DB_UPDATE_PW')
    else
      my_user = location ? location.data[:SQA_ECOMM_DB_READONLY_USER] : ENV.fetch('SQA_ECOMM_DB_READONLY_USER')
      my_pw   = location ? location.data[:SQA_ECOMM_DB_READONLY_PW]   : ENV.fetch('SQA_ECOMM_DB_READONLY_PW')
    end
    Sequel.connect(adapter: 'mysql', user: my_user, host: my_host, database: my_db, password: my_pw)
  end

  def self.db_close( edb )
    edb.disconnect
    nil
  end
end
