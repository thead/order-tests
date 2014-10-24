#!/usr/bin/env ruby

#
# Given a list of orders, compare HJ order data to Oracle
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'compare_hj'

QACommandLine.initialize( 'comparing HighJump order data to Oracle', '    This QA script compares High Jump order data to Oracle' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| CompareHJ.db_check_order_all(o)
}
