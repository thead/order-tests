#!/usr/bin/env ruby

#
# Given a list of gift certificate orders, validate that the E-comm system has the correct data for invoiced GC orders
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'validate_ecomm_orders'

QACommandLine.initialize( 'validating invoiced gift certificate orders (Ecomm DB)', '    This is a QA script for validating invoiced gift certificate orders (Ecomm DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| ValidateEcommOrders.db_check_giftcertificate_all(o) }
