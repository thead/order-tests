#!/usr/bin/env ruby

#
# Uniblab operations
#

require 'curb'
require 'json'

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'

module UniblabOperations
  # Invoke a script on the ecomm server
  # Need ssh keys as the script can only be executed from a certain machine
  def self.uniblab_all( test, state = 'orders' )
    success, result_strings = self.uniblab( test.data, state, test.recorder.warning, test.location, test.recorder )
    test.recorder.log_result( success, "updating #{test.data} via Uniblab" )

    # If we succeeded, only output command line on debug
    # If we failed, dump command line and all captured output to error
    if ( success )
      test.logger.debug "#{result_strings.first}"
    else
      result_strings.each do |result_string|
        test.logger.error "#{result_string}"
      end
    end
    success ? 0 : 1
  end

  def self.uniblab_query_all( test )
    self.uniblab_all( test, 'query' )
  end

  def self.uniblab_duplicate_all( test )
    self.uniblab_all( test, 'orders duplicate' )
  end

  # Lower level method does not need QATestEnv data structure, can be invoked independent of those objects
  # returns pass/fail, array of command and output strings
  def self.uniblab( my_orders, state = 'orders', warning = false, location = nil, recorder = QALogger.new )
    my_uniblab_server  = location ? location.data[:SQA_UNIBLAB_SERVER]        : ENV[:SQA_UNIBLAB_SERVER]
    my_uniblab_version = location ? location.data[:SQA_UNIBLAB_VERSION]       : ENV[:SQA_UNIBLAB_VERSION]
    #my_ecomm_server_url = location ? location.data[:SQA_ECOMM_SERVER_URL]     : ENV[:SQA_ECOMM_SERVER_URL]
    #my_oracle_db       = location ? location.data[:SQA_ORACLE_DB_SERVER]      : ENV[:SQA_ORACLE_DB_SERVER]
    #my_oracle_user     = location ? location.data[:SQA_ORACLE_DB_UPDATE_USER] : ENV[:SQA_ORACLE_DB_UPDATE_USER]
    #my_oracle_pw       = location ? location.data[:SQA_ORACLE_DB_UPDATE_PW]   : ENV[:SQA_ORACLE_DB_UPDATE_PW]

    case state
    when 'orders'
      first_command = "echo \"#{my_orders.join(' ')}\""
      result_string = "successfully POST'ed to e-comm"
    when 'orders duplicate'
      first_command = "echo \"#{my_orders.join(' ')}\""
      result_string = 'skipping order'
    when 'query'
      first_command = '/usr/local/share/uniblab-query.sh'
      result_string = "successfully POST'ed to e-comm"
    else
      return false, [ 'invalid state, no command created' ]
    end

    # create and execute a command line with ``, which allows us to easily capture stdout and check for a success message
    # The specificly invoked remote bundle exec does not return an error code on failure, so we need to check output for a success message
     # NOTE: Do not use --name arg as execution can clash with cron scheduled uniblab commands
    command_string = <<EOF
ssh ubuntu@#{my_uniblab_server} '#{first_command} | sudo docker run --rm -i --env-file /etc/default/uniblab quay.io/modcloth/uniblab:#{my_uniblab_version} -- 2>&1'
EOF
    recorder.logger.debug "Uniblab command line: #{command_string}"
    result_output = `#{command_string}`
    result = $?.success?
    my_orders.each do |order|
      # If warnings enabled, skip result string check
      result &= result_output.include?( result_string ) unless warning
      result &= result_output.include?( "#{order}" )
    end
    return result, [ command_string, result_output ]
  end

  # Check if ecomm order is_capture_complete set
  def self.is_capture_complete( test, order )
    edb = test.edb_ro
    edb_row = edb[ "SELECT is_capture_complete FROM orders WHERE id = #{order}" ].first
    answer = edb_row[:is_capture_complete] ? edb_row[:is_capture_complete] : 0
    answer == 0 ? false : true
  end

  # Give polling 2 hours (1200 checks with a 6 second wait between checks)
  # dev/stage can have long capture delays, may need to be addressed
  def self.is_capture_complete_poll( test )
    QAOperations.poll( test, 1200, 6 ) { |o| self.is_capture_complete( test, o ) }
  end
end
