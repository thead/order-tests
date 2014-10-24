#!/usr/bin/env ruby

#
# Given a list of orders in the order_master/detail tables, create fake HJ shipment_master/detail records
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'create_oracle_shipments'

QACommandLine.initialize( 'creating fake HJ shipment records', '    This is a QA script for creating fake HJ shipment records' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| CreateOracleShipments.db_add_all(o)}
