#!/usr/bin/env ruby

#
# Class to support qa test location data
#

# Store location data need for testing in different locations
class QATestLocation
  attr_reader :location, :env_file
  attr_accessor :data

  # if given location is unknown, use stage for initialization
  def initialize( location = 'stage', env_file = File.expand_path("#{__FILE__}/../../config/stage.sh"))
    @location = location
    @env_file = env_file
    envfile_hash = process_env_file( env_file )
    #ENV explicit settings override values found in a locations config file
    @data = Hash[ SQA_ECOMM_SERVER_URL:        ENV.fetch( 'SQA_ECOMM_SERVER_URL',        envfile_hash['SQA_ECOMM_SERVER_URL'] ),
                  SQA_ECOMM_API_SERVER_URL:    ENV.fetch( 'SQA_ECOMM_API_SERVER_URL',    envfile_hash['SQA_ECOMM_API_SERVER_URL'] ),
                  SQA_ECOMM_DB_SERVER:         ENV.fetch( 'SQA_ECOMM_DB_SERVER',         envfile_hash['SQA_ECOMM_DB_SERVER'] ),
                  SQA_ECOMM_DB:                ENV.fetch( 'SQA_ECOMM_DB',                envfile_hash['SQA_ECOMM_DB'] ),
                  SQA_ECOMM_DB_UPDATE_USER:    ENV.fetch( 'SQA_ECOMM_DB_UPDATE_USER',    envfile_hash['SQA_ECOMM_DB_UPDATE_USER'] ),
                  SQA_ECOMM_DB_UPDATE_PW:      ENV.fetch( 'SQA_ECOMM_DB_UPDATE_PW',      envfile_hash['SQA_ECOMM_DB_UPDATE_PW'] ),
                  SQA_ECOMM_DB_READONLY_USER:  ENV.fetch( 'SQA_ECOMM_DB_READONLY_USER',  envfile_hash['SQA_ECOMM_DB_READONLY_USER'] ),
                  SQA_ECOMM_DB_READONLY_PW:    ENV.fetch( 'SQA_ECOMM_DB_READONLY_PW',    envfile_hash['SQA_ECOMM_DB_READONLY_PW'] ),
                  SQA_ORACLE_DB_SERVER:        ENV.fetch( 'SQA_ORACLE_DB_SERVER',        envfile_hash['SQA_ORACLE_DB_SERVER'] ),
                  SQA_ORACLE_DB_UPDATE_USER:   ENV.fetch( 'SQA_ORACLE_DB_UPDATE_USER',   envfile_hash['SQA_ORACLE_DB_UPDATE_USER'] ),
                  SQA_ORACLE_DB_UPDATE_PW:     ENV.fetch( 'SQA_ORACLE_DB_UPDATE_PW',     envfile_hash['SQA_ORACLE_DB_UPDATE_PW'] ),
                  SQA_ORACLE_DB_READONLY_USER: ENV.fetch( 'SQA_ORACLE_DB_READONLY_USER', envfile_hash['SQA_ORACLE_DB_READONLY_USER'] ),
                  SQA_ORACLE_DB_READONLY_PW:   ENV.fetch( 'SQA_ORACLE_DB_READONLY_PW',   envfile_hash['SQA_ORACLE_DB_READONLY_PW'] ),
                  SQA_HJ_DB_SERVER:            ENV.fetch( 'SQA_HJ_DB_SERVER',            envfile_hash['SQA_HJ_DB_SERVER'] ),
                  SQA_HJ_DB:                   ENV.fetch( 'SQA_HJ_DB',                   envfile_hash['SQA_HJ_DB'] ),
                  SQA_HJ_DB_UPDATE_USER:       ENV.fetch( 'SQA_HJ_DB_UPDATE_USER',       envfile_hash['SQA_HJ_DB_UPDATE_USER'] ),
                  SQA_HJ_DB_UPDATE_PW:         ENV.fetch( 'SQA_HJ_DB_UPDATE_PW',         envfile_hash['SQA_HJ_DB_UPDATE_PW'] ),
                  SQA_HJ_DB_READONLY_USER:     ENV.fetch( 'SQA_HJ_DB_READONLY_USER',     envfile_hash['SQA_HJ_DB_READONLY_USER'] ),
                  SQA_HJ_DB_READONLY_PW:       ENV.fetch( 'SQA_HJ_DB_READONLY_PW',       envfile_hash['SQA_HJ_DB_READONLY_PW'] ),
                  SQA_RUDI_SERVER:             ENV.fetch( 'SQA_RUDI_SERVER',             envfile_hash['SQA_RUDI_SERVER'] ),
                  SQA_RUDI_VERSION:            ENV.fetch( 'SQA_RUDI_VERSION',            envfile_hash['SQA_RUDI_VERSION'] ),
                  SQA_UNIBLAB_SERVER:          ENV.fetch( 'SQA_UNIBLAB_SERVER',          envfile_hash['SQA_UNIBLAB_SERVER'] ),
                  SQA_UNIBLAB_VERSION:         ENV.fetch( 'SQA_UNIBLAB_VERSION',         envfile_hash['SQA_UNIBLAB_VERSION'] ) ]
  end

  def process_env_file( file )
    result_hash = {}
    # regexp is a powerful evil
    IO.foreach( file ){|line| pair = line.scan(/export\s+([A-Z_]+)=(\S+)/).first; result_hash[pair.first] = pair.last}
    return result_hash
  end
end
