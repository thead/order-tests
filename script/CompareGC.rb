#!/usr/bin/env ruby

#
# Given a list of gift certificate orders, validate that the E-comm data matches corresponding Oracle data
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'compare_db_orders'

QACommandLine.initialize( 'database comparing invoiced gift certificate orders (Ecomm/Oracle)', '    This is a QA script for database comparison of invoiced gift certificate orders (Ecomm/Oracle)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| CompareDBOrders.db_check_giftcertificate_all(o) }
