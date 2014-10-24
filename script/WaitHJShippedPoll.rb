#!/usr/bin/env ruby

#
# Given a list of orders, waiting on the Oracle HJ shipment tables to be populated
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_oracle_shipments'

QACommandLine.initialize( 'waiting for HJ shipment (Oracle DB)', '    This QA script waits for HJ shipment (Oracle DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateOracleShipments.db_t_al_host_poll(o) }
