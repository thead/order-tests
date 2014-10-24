#!/usr/bin/env ruby

#
# Find a newly fraud canceled order in ecomm
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_orders'

QACommandLine.initialize( 'finding a newly fraud canceled order', '    This is a QA script for finding a newly fraud canceled order' )
QACommandLine.init_repeat()
exit QACommandLine.process { |o|
  FindOrders.fraud_canceled( o )
  o.recorder.logger.info "Canceled orders #{o.data} found"
  o.data.empty? ? 1:0
}

