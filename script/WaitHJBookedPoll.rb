#!/usr/bin/env ruby

#
# Given a list of orders, wait for the Oracle HJ booking tables to be populated
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_oracle_orders'

QACommandLine.initialize( 'waiting for HJ Booking (Oracle DB)', '    This QA script waits for HJ Booking (Oracle DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateOracleOrders.db_t_al_host_poll(o) }
