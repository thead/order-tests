#!/usr/bin/env ruby

#
# Given a list of gift certificate orders, validate that the Oracle system has the correct data for invoiced GC orders
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_oracle_orders'

QACommandLine.initialize( 'validating invoiced gift certificate orders (Oracle DB)', '    This is a QA script for validating invoiced gift certificate orders (Oracle DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateOracleOrders.db_check_giftcertificate_all(o) }
