#!/usr/bin/env ruby

#
# Given a list of orders, cancel the orders via rudi before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'rudi_operations'

QACommandLine.initialize( 'cancelng order via rudi command line', '    This is a QA script for cancelng orders via the rudi command line' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| RudiOperations.command_line_cancel_all(o) }
