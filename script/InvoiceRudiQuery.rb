#!/usr/bin/env ruby

#
# Invoice all available orders via rudi before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'rudi_operations'

QACommandLine.initialize( 'invoicing all available orders via rudi command line', '    This is a QA script for invoicing all available orders via the rudi command line' )
exit QACommandLine.process { |o| RudiOperations.command_line_invoice_query_all(o) }
