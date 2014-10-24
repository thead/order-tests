#!/usr/bin/env ruby

#
# Find a random valid item
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'find_db_items'

QACommandLine.initialize( 'finding a valid random item', '    This is a QA script for finding a valid random item' )
exit QACommandLine.process { |o|
  upc,sku,quantity = FindDBItems.find_random(o.edb_ro, o.odb_ro)
  o.recorder.logger.info "Randomly selected upc: #{upc}, sku: #{sku}, quantity in oracle #{quantity}"
  (not upc) or (not sku) ? 1:0
}

