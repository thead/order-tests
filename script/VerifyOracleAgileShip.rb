#!/usr/bin/env ruby

#
# Given a list of orders, validate that the Oracle shipment table has the correct data
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_oracle_shipments'

QACommandLine.initialize( 'validating order shipments (Oracle DB)', '    This is a QA script for validating order shipments (Oracle DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateOracleShipments.db_check_agile_all(o) }
