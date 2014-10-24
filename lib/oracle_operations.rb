#!/usr/bin/env ruby

#
# Support Oracle connection operations
#

require 'oci8'

module QAOracle
  def self.db_connect( location = nil, update = false )
    if update
      my_user = location ? location.data[:SQA_ORACLE_DB_UPDATE_USER] : ENV.fetch('SQA_ORACLE_DB_UPDATE_USER')
      my_pw   = location ? location.data[:SQA_ORACLE_DB_UPDATE_PW]   : ENV.fetch('SQA_ORACLE_DB_UPDATE_PW')
    else
      my_user = location ? location.data[:SQA_ORACLE_DB_READONLY_USER] : ENV.fetch('SQA_ORACLE_DB_READONLY_USER')
      my_pw   = location ? location.data[:SQA_ORACLE_DB_READONLY_PW]   : ENV.fetch('SQA_ORACLE_DB_READONLY_PW')
    end
    my_db_server = '//' + (location ? location.data[:SQA_ORACLE_DB_SERVER]: ENV.fetch('SQA_ORACLE_DB_SERVER'))
    OCI8.new( my_user, my_pw, my_db_server )
  end

  def self.db_close( odb )
    odb.logoff()
    nil
  end
end
