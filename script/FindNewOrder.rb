#!/usr/bin/env ruby

#
# Find a newly created order in ecomm
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_orders'

QACommandLine.initialize( 'finding a newly created order', '    This is a QA script for finding a new order' )
QACommandLine.init_repeat()
exit QACommandLine.process { |o|
  FindOrders.new( o )
  o.recorder.logger.info "New orders #{o.data} found"
  o.data.empty? ? 1:0
}

