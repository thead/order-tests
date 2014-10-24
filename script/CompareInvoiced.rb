#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle data for invoiced orders
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'compare_db_orders'

QACommandLine.initialize( 'database comparing invoiced orders (Ecomm/Oracle)', '    This is a QA script for database comparison of invoiced orders (Ecomm/Oracle)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| CompareDBOrders.db_check_invoiced_all(o) }
