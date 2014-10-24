#!/usr/bin/env ruby

#
# Given a list of orders already shipped via uniblab, re-update orders via uniblab before returning
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'uniblab_operations'

QACommandLine.initialize( 'reshipping order via uniblab command line', '    This is a QA script for reshipping orders via the uniblab command line' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| UniblabOperations.uniblab_duplicate_all(o) }
