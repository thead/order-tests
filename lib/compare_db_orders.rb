#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'ecomm_queries'
require 'manual_operations'
require 'compare_db_headers'
require 'compare_db_lines'
require 'compare_db_payments'
require 'compare_db_customers'
require 'compare_db_utils'

module CompareDBOrders
  # Manually validate orders in Ecomm
  def self.manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'E-comm to Oracle order DB', manual )
  end

  # We support 5 testing states at present:
  #   booked: An order has been placed in oracle via rudi
  #   captured: An order has had final funds capture completed
  #   invoiced: An order is complete and funds captured
  #   canceled: An order is canceled for fraud or fully scratched
  #   giftcertificate: A gift certificate order

  def self.db_check_all_state( test, state )
    error_count = 0
    test.data.each do |order|
      test.logger.info "Comparing Ecomm/Oracle DBs for #{order}"
      order_error_count = test.recorder.indent_logging { CompareDBOrders.send("db_check_#{state}", test.edb_ro, test.odb_ro, order, test.recorder ) }
      test.recorder.log_result( order_error_count == 0, "comparision of Ecomm/Oracle DBs for #{order}" )
      error_count += order_error_count
    end
    error_count
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.db_check_captured_all( test )
    self.db_check_all_state( test, 'captured' )
  end

  def self.db_check_giftcertificate_all( test )
    self.db_check_all_state( test, 'giftcertificate' )
  end

  def self.db_check_invoiced_all( test )
    self.db_check_all_state( test, 'invoiced' )
  end

  def self.db_check_canceled_all( test )
    self.db_check_all_state( test, 'canceled' )
  end

  def self.db_check_booked_all( test )
    self.db_check_all_state( test, 'booked' )
  end

  # Lower level routines

  def self.db_check_canceled( edb, odb, order, recorder = QALogger.new )
    error_count = CompareDBHeaders.db_check( edb, odb, order, 'canceled', recorder )
    error_count += CompareDBLines.db_check( edb, odb, order, 'canceled', recorder )
  end

  def self.db_check_captured( edb, odb, order, recorder = QALogger.new )
    # Get the order line items
    edb_items = QAEcommQuery.get_array( edb, order, 'items', recorder )
    return 1 unless edb_items

    error_count = 0
    edb_items.each do |edb_item|
      sql_cmd = <<EOF
  SELECT quantity_shipped, tracking_number,
         SUM(quantity_shipped) OVER (PARTITION BY line_number) summed_quantity,
         CAST(line_number AS INT) AS test_label
    FROM xxmc.t_al_host_shipment_detail
   WHERE order_number = #{order} AND
         line_number = #{edb_item[:line_number]}
ORDER BY line_number
EOF

      computed_shipped = edb_item[:quantity] - edb_item[:cancel_quantity]

      checks = {
        summed_quantity:    { value: computed_shipped,     label: 'computed quantity shipped' },
      }

      if computed_shipped == 0
        checks[:tracking_number] = { value: nil,    label: 'tracking_number field' }
      end

      error_count += CompareDBUtils.record_check(odb, sql_cmd, checks, "shipment detail line", recorder )
    end

    # Make sure each Ecomm shipment line exists in Oracle shipment details
    edb_shipments = QAEcommQuery.get_array( edb, order, 'shipments', recorder )
    return 1 unless edb_shipments

    edb_shipments.each do |shipment|
      sql_cmd = <<EOF
  SELECT tracking_number, record_create_date
    FROM xxmc.t_al_host_shipment_detail
   WHERE order_number = #{order}
GROUP BY tracking_number, record_create_date
  HAVING tracking_number = #{shipment[:tracking_number]}
EOF

      # record create date came from HJ in UTC and was not converted to PDT in Oracle
      checks = {
        record_create_date: { value: shipment[:shipped_at], label: "shipment date for tracking number #{shipment[:tracking_number]}" }
      }

      error_count += CompareDBUtils.record_check(odb, sql_cmd, checks, "shipment detail lines by tracking number", recorder )
    end

    error_count
  end

  def self.db_check_giftcertificate( edb, odb, order, recorder = QALogger.new )
    error_count = CompareDBHeaders.db_check( edb, odb, order, 'giftcertificate', recorder )
    error_count += CompareDBLines.db_check( edb, odb, order, 'giftcertificate', recorder )
    error_count += CompareDBPayments.db_check( edb, odb, order, 'giftcertificate', recorder )
    error_count += CompareDBCustomers.db_check( edb, odb, order, 'giftcertificate', recorder )
  end

  def self.db_check_invoiced( edb, odb, order, recorder = QALogger.new )
    error_count = CompareDBHeaders.db_check( edb, odb, order, 'invoiced', recorder )
    error_count += CompareDBLines.db_check( edb, odb, order, 'invoiced', recorder )
    error_count += CompareDBLines.db_check_shipping( edb, odb, order, recorder )
    error_count += CompareDBLines.db_check_salestax( edb, odb, order, recorder )
    error_count += CompareDBPayments.db_check( edb, odb, order, 'invoiced', recorder )
  end

  def self.db_check_booked( edb, odb, order, recorder = QALogger.new )
    error_count = CompareDBHeaders.db_check( edb, odb, order, 'booked', recorder )
    error_count += CompareDBLines.db_check( edb, odb, order, 'booked', recorder )
    error_count += CompareDBCustomers.db_check( edb, odb, order, 'booked', recorder )
  end
end
