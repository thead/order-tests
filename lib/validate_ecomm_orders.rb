#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm system has the correct data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'ecomm_queries'
require 'manual_operations'

module ValidateEcommOrders
  # Manually validate orders in Ecomm
  def self.manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'E-comm order DB', manual )
  end

  # We support 4 testing states at present:
  #   new: An order just created in Ecomm
  #   booked: An order just got booked in oracle via rudi
  #   captured: An order just got shipped in ecomm via uniblab
  #   invoiced: An order is complete
  #   canceled: An order is canceled for fraud

  # Access the Ecomm mysql db via the sequel gem
  def self.db_check_all_state( test, state )
    error_count = 0
    test.data.each do |order|
      test.logger.info "Checking #{state} order status in Ecomm DB for #{order}"
      order_error_count = test.recorder.indent_logging { self.db_check( test.edb_ro, order, state, test.recorder ) }
      test.recorder.log_result( order_error_count == 0, "Ecomm DB check for #{order}" )
      error_count += order_error_count
    end
    error_count
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.db_check_canceled_all( test )
    self.db_check_all_state( test, 'canceled' )
  end

  def self.db_check_giftcertificate_all( test )
    self.db_check_all_state( test, 'giftcertificate' )
  end

  def self.db_check_invoiced_all( test )
    self.db_check_all_state( test, 'invoiced' )
  end

  def self.db_check_captured_all( test )
    self.db_check_all_state( test, 'captured' )
  end

  def self.db_check_booked_all( test )
    self.db_check_all_state( test, 'booked' )
  end

  def self.db_check_new_all( test )
    self.db_check_all_state( test, 'new' )
  end

  # One Ecomm query is sufficient for our current validations
  # Depending on the state, we check different field/values
  def self.db_check( edb, order, state, recorder = QALogger.new )
    db_row = QAEcommQuery.get_row( edb, order, 'order+state', recorder )
    # if we dont have a record at all, skip data checks and fail out
    if (not db_row) || db_row.empty?
      recorder.logger.error "No record found for #{order}"
      return 1
    end

    error_count = 0
    case state
    when 'new'
      # using hard coded internal_state_id as a new order should = 0, which is not in the internal_states table
      error_count += 1 unless QAOperations.data_check_basic( db_row[:state], 'state', 'pending', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:checkout_complete], 'checkout_complete', true, recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:finance_state], 'finance state', 'pending', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:internal_state_id], 'internal state', 0, recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:is_capture_complete], 'is_capture_complete', false, recorder )
    when 'booked'
      error_count += 1 unless QAOperations.data_check_basic( db_row[:finance_state], 'finance state', 'booked', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:internal_state], 'internal state', 'Fulfillment started', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:state], 'state', 'pending', recorder )
    when 'invoiced'
      error_count += 1 unless QAOperations.data_check_basic( db_row[:state], 'state', 'shipped', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:checkout_complete], 'checkout_complete', true, recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:finance_state], 'finance state', 'invoiced', recorder )
    when 'giftcertificate'
      error_count += 1 unless QAOperations.data_check_basic( db_row[:state], 'state', 'shipped', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:finance_state], 'finance state', 'invoiced', recorder )
    when 'canceled'
      error_count += 1 unless QAOperations.data_check_basic( db_row[:internal_state_id], 'internal state', nil, recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:state], 'state', 'canceled', recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:checkout_complete], 'checkout_complete', true, recorder )
      error_count += 1 unless QAOperations.data_check_basic( db_row[:finance_state], 'finance state', 'cancelled', recorder )
    when 'captured'
      error_count += 1 unless QAOperations.data_check_basic( db_row[:internal_state], 'internal state', 'Fulfillment completed', recorder )
    else
      recorder.logger.error "db_check received unknown state #{state}"
      return nil
    end

    error_count
  end

  # Check if ecomm order is booked
  def self.is_booked( test, order )
    db_row = QAEcommQuery.get_row( test.edb_ro, order, 'order+state', test.recorder )
    (db_row) && db_row[:finance_state] == 'booked'
  end

  def self.is_booked_poll( test, wait_cycles = 80 )
    QAOperations.poll( test, wait_cycles ) { |o| self.is_booked( test, o ) }
  end

  def self.is_booked_longpoll( test )
    self.is_booked_poll( test, 240 )
  end

  # Check if ecomm order is invoiced
  def self.is_invoiced( test, order )
    db_row = QAEcommQuery.get_row( test.edb_ro, order, 'order+state', test.recorder )
    (db_row) && db_row[:finance_state] == 'invoiced'
  end

  def self.is_invoiced_poll( test )
    QAOperations.poll( test ) { |o| self.is_invoiced( test, o ) }
  end

  # Check if ecomm order is uniblab shipped
  def self.is_shipped( test, order )
    db_row = QAEcommQuery.get_row( test.edb_ro, order, 'order+state', test.recorder )
    (db_row) && db_row[:internal_state] == 'Fulfillment completed'
  end

  def self.is_shipped_poll( test )
    QAOperations.poll( test ) { |o| self.is_shipped( test, o ) }
  end

  def self.is_canceled( test, order )
    db_row = QAEcommQuery.get_row( test.edb_ro, order, 'order+state', test.recorder )
    (db_row) && db_row[:finance_state] == 'cancelled'
  end

  def self.is_canceled_poll( test )
    QAOperations.poll( test ) { |o| self.is_canceled( test, o ) }
  end
end
