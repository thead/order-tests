#!/usr/bin/env ruby

#
# Find a newly shipped order in ecomm
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_orders'

QACommandLine.initialize( 'finding a newly shipped order', '    This is a QA script for finding a newly shipped order' )
QACommandLine.init_repeat()
exit QACommandLine.process { |o|
  FindOrders.shipped( o )
  o.recorder.logger.info "Shipped orders #{o.data} found"
  o.data.empty? ? 1:0
}

