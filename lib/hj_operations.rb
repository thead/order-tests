#!/usr/bin/env ruby

#
# Basic HighJump connection operations
#
require 'tiny_tds'

module QAHighjump
  # An optional location object can be provided, otherwise use ENV vars or hard coded stage values
  # Can use either a readonly or read-write user depending on requirements
  def self.db_connect( location = nil, update = false )
    my_host   = location ? location.data[:SQA_HJ_DB_SERVER]        : ENV.fetch('SQA_HJ_DB_SERVER')
    my_db     = location ? location.data[:SQA_HJ_DB]               : ENV.fetch('SQA_HJ_DB')
    if update
      my_user = location ? location.data[:SQA_HJ_DB_UPDATE_USER]   : ENV.fetch('SQA_HJ_DB_UPDATE_USER')
      my_pw   = location ? location.data[:SQA_HJ_DB_UPDATE_PW]     : ENV.fetch('SQA_HJ_DB_UPDATE_PW')
    else
      my_user = location ? location.data[:SQA_HJ_DB_READONLY_USER] : ENV.fetch('SQA_HJ_DB_READONLY_USER')
      my_pw   = location ? location.data[:SQA_HJ_DB_READONLY_PW]   : ENV.fetch('SQA_HJ_DB_READONLY_PW')
    end
    TinyTds::Client.new( :username => my_user, :password => my_pw, :host => my_host, :database => my_db )
  end

  def self.db_close( hjdb )
    hjdb.close
    nil
  end
end
