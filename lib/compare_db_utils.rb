#!/usr/bin/env ruby

#
# This module contains only simple utilities used by other comparison modules
#

require 'digest'

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'ecomm_queries'

module CompareDBUtils
  # Find the original parent order in a possible chain of child orders
  def self.get_root_order_parent( edb, child, parent, recorder = QALogger.new )
    return nil unless parent
    while parent
      child = parent
      parent = QAEcommQuery.get_field( edb, child, 'order parent', recorder )
    end
    child
  end

  # Compute if billing and shipping addresses are the same
  def self.bill_ship_equal?( order, addresses, recorder = QALogger.new )
    bill_name = ship_name = nil
    addresses.each do |address|
      ship_name = self.compute_sha512_address( order, address, recorder ) if address[:type] == 'ShippingAddress'
      bill_name = self.compute_sha512_address( order, address, recorder ) if address[:type] == 'BillingAddress'
    end
    (ship_name == bill_name) and ship_name
  end

  # Compute the sha512 hash for concatinated order/address data
  def self.compute_sha512_address( order, address, recorder = QALogger.new )
    my_string = "#{order[:account_id]}|#{address[:region_id]}|#{address[:city]}|#{address[:firstname]}|#{address[:lastname]}|#{address[:postal_code]}|#{address[:street_1]}|#{address[:street_2]}"
    recorder.logger.debug "Concatinated address: #{my_string}"
    Digest::SHA512.hexdigest(my_string)
  end

  def self.final_check(error_count, rows, order, label, recorder = QALogger.new)
    if rows < 1
      error_count += 1
      recorder.logger.error "No records found for #{order} found in #{label}"
    end
    return error_count
  end

  # For the given query, check a hash of record key and value/label pairs with debugging/reporting support
  def self.record_check(odb, sql_str, checks, label, recorder = QALogger.new )
    self.record_validate(odb, sql_str, checks, [], label, recorder )
  end

  def self.record_warning(odb, sql_str, warnings, label, recorder = QALogger.new )
    self.record_validate(odb, sql_str, [], warnings, label, recorder )
  end

  def self.record_validate(odb, sql_str, checks, warnings, label, recorder = QALogger.new )
    recorder.logger.debug "SQL query is:\n#{sql_str}"

    cursor = odb.parse( sql_str )
    cursor.exec()

    found = false
    error_count = 0
    while record = cursor.fetch_hash()
      # The sql command includes a test_label field, add it to the test output string
      if record['TEST_LABEL']
        xlabel = " (#{record['TEST_LABEL']})"
      else
        xlabel = ''
      end
      found = true
      warnings.each { |key,vhash|
        error_count += 1 unless QAOperations.data_check( record[key.to_s.upcase], "the ODB #{key} field in the #{label}#{xlabel}", vhash[:value], "the EDB #{vhash[:label]}", true, recorder )
      }
      checks.each { |key,vhash|
        error_count += 1 unless QAOperations.data_check( record[key.to_s.upcase], "the ODB #{key} field in the #{label}#{xlabel}", vhash[:value], "the EDB #{vhash[:label]}", false, recorder )
      }
    end

    recorder.log_result( found, "verification that record(s) for the #{label} found" )
    error_count += 1 unless found

    return error_count
  end
end
