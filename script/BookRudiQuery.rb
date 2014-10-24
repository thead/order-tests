#!/usr/bin/env ruby

#
# Book all orders who's 1 hour delay has expired via rudi before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'rudi_operations'

QACommandLine.initialize( 'booking all 1 hour delay expired orders via rudi command line', '    This is a QA script for booking all 1 hour delay expired orders via the rudi command line' )
exit QACommandLine.process { |o| RudiOperations.command_line_query_all(o) }
