#!/usr/bin/env ruby

#
# Find a Ecomm sku given an Ecomm upc/Oracle sku
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'ecomm_queries'

QACommandLine.initialize( 'converting an Ecomm upc to a sku', '    This is a QA script for converting an Ecomm upc to a sku' )
QACommandLine.init_extra_args( 'data' )
exit QACommandLine.process { |o|
  error_count = 0
  o.data.each do |upc|
    sku = QAEcommQuery.get_field(o.edb_ro, upc, 'sku', o.recorder)
    o.recorder.logger.info "UPC: #{upc} SKU: #{sku}"
    error_count += (not upc) || (not sku) ? 1:0
  end
  error_count
}

