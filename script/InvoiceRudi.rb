#!/usr/bin/env ruby

#
# Given a list of orders, invoice the orders via rudi before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'rudi_operations'

QACommandLine.initialize( 'invoicing order via rudi command line', '    This is a QA script for invoicing orders via the rudi command line' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| RudiOperations.command_line_invoice_all(o) }
