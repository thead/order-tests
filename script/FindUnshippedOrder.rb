#!/usr/bin/env ruby

#
# Find an unshipped oracle order at least a day old
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_orders'

QACommandLine.initialize( 'finding an unshipped day+ old order', '    This is a QA script for finding an unshipped day+ old order' )
QACommandLine.init_repeat()
exit QACommandLine.process { |o|
  FindOrders.unshipped( o )
  o.recorder.logger.info "Unshipped orders #{o.data} found"
  o.data.empty? ? 1:0
}

