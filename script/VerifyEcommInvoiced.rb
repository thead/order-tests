#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm system has the correct data after invoicing
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_ecomm_orders'

QACommandLine.initialize( 'validating invoiced orders (Ecomm DB)', '    This is a QA script for validating invoiced orders (Ecomm DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateEcommOrders.db_check_invoiced_all(o) }
