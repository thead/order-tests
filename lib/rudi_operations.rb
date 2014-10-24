#!/usr/bin/env ruby

#
# Given a list of orders, push the orders to fulfillment before returning
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'manual_operations'

module RudiOperations
  # Invoke a script on the ecomm server
  # Need ssh keys as the script can only be executed from a certain machine
  def self.command_line_all( test, state = 'orders', command = 'book' )
    test.logger.info #{command} #{test.data} via Rudi"
    success, result_strings = self.command_line( test.data, state, command, test.location, test.recorder )
    test.recorder.log_result( success, "#{command} #{test.data} via Rudi" )

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

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.command_line_query_all( test )
    self.command_line_all( test, 'query' )
  end

  def self.command_line_invoice_all( test )
    self.command_line_all( test, 'orders', 'invoice' )
  end

  def self.command_line_invoice_query_all( test )
    self.command_line_all( test, 'query', 'invoice' )
  end

  def self.command_line_cancel_all( test )
    self.command_line_all( test, 'orders', 'cancel' )
  end

  def self.command_line_cancel_query_all( test )
    self.command_line_all( test, 'query', 'cancel' )
  end

  # Lower level method does not need QATestEnv data structure, can be invoked independent of those objects
  # returns pass/fail, array of command and output strings
  def self.command_line( my_orders, state = 'orders', command = 'book', location = nil, recorder = QALogger.new )
    my_rudi_server     = location ? location.data[:SQA_RUDI_SERVER]           : ENV[:SQA_RUDI_SERVER]
    my_rudi_version    = location ? location.data[:SQA_RUDI_VERSION]          : ENV[:SQA_RUDI_VERSION]
    #my_ecomm_db_server = location ? location.data[:SQA_ECOMM_DB_SERVER]       : ENV[:SQA_ECOMM_DB_SERVER]
    #my_ecomm_db        = location ? location.data[:SQA_ECOMM_DB]              : ENV[:SQA_ECOMM_DB]
    #my_ecomm_user      = location ? location.data[:SQA_ECOMM_DB_UPDATE_USER]  : ENV[:SQA_ECOMM_DB_UPDATE_USER]
    #my_ecomm_pw        = location ? location.data[:SQA_ECOMM_DB_UPDATE_PW]    : ENV[:SQA_ECOMM_DB_UPDATE_PW]
    #my_oracle_db       = location ? location.data[:SQA_ORACLE_DB_SERVER]      : ENV[:SQA_ORACLE_DB_SERVER]
    #my_oracle_user     = location ? location.data[:SQA_ORACLE_DB_UPDATE_USER] : ENV[:SQA_ORACLE_DB_UPDATE_USER]
    #my_oracle_pw       = location ? location.data[:SQA_ORACLE_DB_UPDATE_PW]   : ENV[:SQA_ORACLE_DB_UPDATE_PW]

    case state
    when 'orders'
      first_command = "echo \"#{my_orders.join(' ')}\""
    when 'query'
      first_command = "/usr/local/share/rudi-#{command}-query.sh"
    else
      return false, [ 'invalid state, no command created' ]
    end

    case command
    when 'book'
      command_output = 'marking order as booked'
      xtra_args = '--mark-fulfillment-state="True"'
    when 'invoice'
      command_output = 'marking order as invoiced'
      xtra_args = ''
    when 'cancel'
      command_output = 'marking order as cancelled'
      xtra_args = ''
    else
      return false, [ 'invalid command, no command created' ]
    end

    # create and execute a command line with ``, which allows us to easily capture stdout and check for a success message 
    # The specificly invoked remote bundle exec does not return an error code on failure, so we need to check output for a success message
    # Redirect stderr as stdout messages moved to stderr
    # NOTE: Do not use --name arg as execution can clash with cron scheduled rudi commands
    command_string = <<EOF
ssh ubuntu@#{my_rudi_server} '#{first_command} | sudo docker run --rm -i --env-file '/etc/default/rudi-#{command}' quay.io/modcloth/rudi:#{my_rudi_version} #{command} 2>&1'
EOF
    recorder.logger.debug "Rudi command line: #{command_string}"
    result_output = `#{command_string}`
    result = $?.success?
    my_orders.each do |order|
      result &= result_output.include?("successfully processed order")
      result &= result_output.include?("order=#{order}")
      result &= result_output.include?("#{command_output}")
    end
    return result, [ command_string, result_output ]
  end
end
