#!/usr/bin/env ruby

#
# Given a list of orders, expire any 1 hour delay before being booked
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'ecomm_updates'

QACommandLine.initialize( 'expire 1 hour order delay', '    This is a QA script for expiring the 1 hour order delay' )
QACommandLine.init_extra_args( 'orders' )
exit QACommandLine.process { |o| QAEcommUpdates.last_viewed_in_admin_now_all(o) }
