#!/usr/bin/env ruby

#
# Find a Ecomm upc given an Ecomm sku
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'ecomm_queries'

QACommandLine.initialize( 'converting an Ecomm sku to a upc', '    This is a QA script for converting an Ecomm sku to a upc' )
QACommandLine.init_extra_args( 'data' )
exit QACommandLine.process { |o|
  error_count = 0
  o.data.each do |sku|
    upc = QAEcommQuery.get_field(o.edb_ro, sku, 'upc', o.recorder)
    o.recorder.logger.info "UPC: #{upc} SKU: #{sku}"
    error_count += (not upc) || (not sku) ? 1:0
  end
  error_count
}

