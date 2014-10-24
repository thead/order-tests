#!/usr/bin/env ruby

#
# Given a list of orders, wait for funds capture to complete in ecomm
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'uniblab_operations'

QACommandLine.initialize( 'waiting for capture complete (Ecomm DB)', '    This QA script waits for capture complete (Ecomm DB)' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| UniblabOperations.is_capture_complete_poll(o) }
