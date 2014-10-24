#!/usr/bin/env ruby

#
# Given a list of orders, update orders via uniblab before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'uniblab_operations'

QACommandLine.initialize( 'updating order via uniblab command line', '    This is a QA script for updating orders via the uniblab command line' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| UniblabOperations.uniblab_all(o) }
