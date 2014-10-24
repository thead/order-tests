#!/usr/bin/env ruby

#
# Update all outstanding orders via uniblab before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'uniblab_operations'

QACommandLine.initialize( 'updating all outstanding orders via uniblab command line', '    This is a QA script for updating all outstanding orders via the uniblab command line' )
exit QACommandLine.process { |o| UniblabOperations.uniblab_query_all(o) }
