#!/usr/bin/env ruby

#
# Given a list of orders, wait for rudi cancel
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_ecomm_orders'

QACommandLine.initialize( 'waiting for rudi cancel operation', '    This QA script waits for rudi cancel operation to complete' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateEcommOrders.is_canceled_poll(o) }
