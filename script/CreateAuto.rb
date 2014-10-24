#!/usr/bin/env ruby

#
# Create a new orders
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'create_ecomm_orders'

QACommandLine.initialize( 'creation of a new orders in Ecomm', '    This is a QA script for creating new orders' )
QACommandLine.init_extra_args( 'config_files' )
exit QACommandLine.process { |o|
  return_code = CreateEcommOrders.api_add(o)
  o.data.each do |order|
    o.logger.info "Created order is #{order}"
  end
  return_code
}

