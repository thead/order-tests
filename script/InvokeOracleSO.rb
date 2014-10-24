#!/usr/bin/env ruby

#
# Invoke Oracle concurrent program for given order(s)
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'oracle_programs'

QACommandLine.initialize( 'invoking Oracle XXMC Create Sales Order/Outbound to HJ', '    This is a QA script for invoking the Oracle concurrent Sales Order programs' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| OracleProgram.invoke_sales_order_all(o)}
