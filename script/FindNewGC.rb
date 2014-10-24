#!/usr/bin/env ruby

#
# Find a newly created gift certificate order in ecomm
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_orders'

QACommandLine.initialize( 'finding a newly created GC order', '    This is a QA script for finding a new GC order' )
QACommandLine.init_repeat()
exit QACommandLine.process { |o|
  FindOrders.new_gc( o )
  o.recorder.logger.info "New GC orders #{o.data} found"
  o.data.empty? ? 1:0
}

