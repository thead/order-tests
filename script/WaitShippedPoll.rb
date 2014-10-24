#!/usr/bin/env ruby

#
# Given a list of orders, wait for uniblab shipping
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_oracle_shipments'

QACommandLine.initialize( 'waiting for uniblab ship operation', '    This QA script waits for uniblab ship operation to complete' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateOracleShipments.is_shipped_poll(o) }
