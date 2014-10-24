#!/usr/bin/env ruby

#
# Given a list of orders, wait for HJ to download them
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_hj_orders'

QACommandLine.initialize( 'waiting for HighJump download operation', '    This QA script waits for High Jump download operation to complete' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateHJOrders.is_downloaded_poll(o) }
