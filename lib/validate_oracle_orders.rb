#!/usr/bin/env ruby

#
# Given a list of orders, validate that the Oracle system has the correct order data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'manual_operations'
require 'validate_oracle_utils'
require 'ecomm_queries'

module ValidateOracleOrders
  # Manually validate orders in Oracle
  def self.manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'Oracle order DB', manual )
  end

  # We support 5 testing states at present:
  #   new: An order just created in ecomm
  #   booked: A new order is added to oracle via rud
  #   invoiced: An order is complete
  #   canceled: An order has been fully canceled
  #   giftcertificate: A gift certificate order

  def self.db_check_all_state( test, state )
    test.data.reduce(0) do |error_count, order|
      test.logger.info "Checking #{state} order status in Oracle DB for #{order}"
      error_count_add  = test.recorder.indent_logging { ValidateOracleOrders.send("db_check_salesorder_header_#{state}", test, order ) }
      error_count_add += test.recorder.indent_logging { ValidateOracleOrders.send("db_check_salesorder_line_#{state}", test, order ) }
      error_count_add += test.recorder.indent_logging { ValidateOracleOrders.send("db_check_salesorder_payment_#{state}", test, order ) }
      if [ 'booked', 'giftcertificate' ].include? state
        error_count_add += test.recorder.indent_logging { ValidateOracleOrders.send("db_check_customer_detail", test, order ) }
      end
      test.recorder.log_result( error_count_add == 0, "Oracle DB check for #{order}" )

      error_count + error_count_add
    end
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
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

  def self.db_check_new_all( test )
    self.db_check_all_state( test, 'new' )
  end

  # Lower level method does not require QATestEnv, can be invoked independent of those objects
  # optionally provide a recorder to exploit logging/debugging support

  def self.db_check_salesorder_header_giftcertificate( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_headers_v2 WHERE order_number = #{order} AND action = 'GC'"

    warnings = { status: 'NEW' }

    checks = { error_message: nil, transactional_curr_code: 'USD', order_type: 'Gift Certificate Order',
               order_source: 'ModCloth.com', sold_from_org_id: 'PIT', special_pkg_instructions: nil, gift_wrap: 'N', shipping_method: 'VTL'  }

    ValidateOracleUtils.record_validate(test.odb_ro, sql_cmd, checks, warnings, "'S' sales order gift certificate headers", test.recorder )
  end

  def self.db_check_salesorder_header_invoiced( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_headers_v2 WHERE order_number = #{order} AND action = 'S'"

    warnings = { status: 'NEW', error_message: nil }

    checks = { transactional_curr_code: 'USD', order_type: 'Standard Sales Order',
               order_source: 'ModCloth.com', sold_from_org_id: 'PIT', special_pkg_instructions: nil, gift_wrap: 'N'  }

    ValidateOracleUtils.record_validate(test.odb_ro, sql_cmd, checks, warnings, "'S' sales order headers", test.recorder )
  end

  def self.db_check_salesorder_header_canceled( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_headers_v2 WHERE order_number = #{order} AND action = 'C'"

    warnings = { status: 'NEW' }

    checks = { error_message: nil, transactional_curr_code: 'USD', order_type: 'Standard Sales Order',
               order_source: 'ModCloth.com', sold_from_org_id: 'PIT', special_pkg_instructions: nil, gift_wrap: 'N'  }

    ValidateOracleUtils.record_validate(test.odb_ro, sql_cmd, checks, warnings, "'C' sales order headers", test.recorder )
  end

  def self.db_check_salesorder_header_booked( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_headers_v2 WHERE order_number = #{order} AND action = 'N'"

    warnings = { status: 'NEW' }

    checks = { error_message: nil, transactional_curr_code: 'USD', order_type: 'Standard Sales Order',
               order_source: 'ModCloth.com', sold_from_org_id: 'PIT', special_pkg_instructions: nil, gift_wrap: 'N'  }

    ValidateOracleUtils.record_validate(test.odb_ro, sql_cmd, checks, warnings, "'N' sales order headers", test.recorder )
  end

  def self.db_check_salesorder_header_new( test, order )
    # Check sales order header, should not be there
    sql_str = "SELECT * FROM xxmc.xxmc_salesorder_headers_v2 WHERE order_number = #{order} AND action = 'N'"
    ValidateOracleUtils.record_does_not_exist(test.odb_ro, sql_str, "sales order headers records with action='N'", test.recorder )
  end

  def self.db_check_salesorder_line_canceled( test, order )
    sql_cmd = <<EOF
SELECT l.error_message, l.creation_date, uom_code, fob_point, tracking_number,
       shipment_number, shipping_warehouse, CAST(line_number AS INT) AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order} AND
       h.action = 'C' AND
       l.action = 'C'
EOF

    checks = { error_message: nil, creation_date: nil, uom_code: 'Each', fob_point: 'Shipping Point',
               shipment_number: nil, shipping_warehouse: '83', tracking_number: nil  }

    ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "'C' sales order line", test.recorder )
  end

  def self.db_check_salesorder_line_giftcertificate( test, order )
    sql_cmd = <<EOF
SELECT l.error_message, l.creation_date, uom_code, fob_point,
       discount_value, discount_name, ordered_quantity, shipped_quantity,
       shipment_number, shipping_warehouse, l.action, line_number,
       order_line_type, sku, final_sale, tracking_number,
       CAST(line_number AS INT) AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order}
EOF

    checks = { error_message: nil, creation_date: nil, uom_code: 'Each', fob_point: 'Shipping Point',
               discount_value: 0, discount_name: nil, ordered_quantity: 1, shipped_quantity: 1,
               shipment_number: 1, shipping_warehouse: '83', action: 'N', line_number: 1,
               order_line_type: 'SO Invoice Only Line', sku: 'GIFTCERT', final_sale: 'Y',
               tracking_number: nil  }

    ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "sales order gift certificate line", test.recorder )
  end

  def self.db_check_salesorder_line_invoiced( test, order )
    sql_cmd = <<EOF
SELECT l.error_message, l.creation_date, uom_code, fob_point,
       shipment_number, shipping_warehouse, CAST(line_number AS INT) AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order} AND
       h.action IN ('S','C') AND
       l.action IN ('S','C','U')
EOF

    checks = { error_message: nil, creation_date: nil, uom_code: 'Each', fob_point: 'Shipping Point',
               shipment_number: 1, shipping_warehouse: '83' }

    error_count = ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "'SCU' sales order line", test.recorder )

    sql_cmd = <<EOF
SELECT l.error_message, l.creation_date, uom_code, fob_point,
       discount_value, discount_name, ordered_quantity, shipped_quantity,
       shipment_number, shipping_warehouse,
       CAST(line_number AS INT) AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order} AND
       h.action IN ('S','C') AND l.action = 'N' AND
       ( l.sku = 'SHIPPING' OR l.sku = 'SALESTAX' )
EOF

    checks = { error_message: nil, creation_date: nil, uom_code: 'Each', fob_point: 'Shipping Point',
               discount_value: 0, discount_name: nil, ordered_quantity: 1, shipped_quantity: 1,
               shipment_number: 1, shipping_warehouse: '83'  }

    error_count + ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "sales order shipping/tax line", test.recorder )
  end

  def self.db_check_salesorder_line_booked( test, order )
    sql_cmd = <<EOF
SELECT l.error_message, l.creation_date, uom_code, fob_point,
       shipment_number, actual_ship_date, tracking_number, shipping_warehouse, CAST(line_number AS INT) AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order} AND
       h.action = 'N' AND
       l.action = 'N'
EOF

    checks = { error_message: nil, creation_date: nil, uom_code: 'Each', fob_point: 'Shipping Point',
               shipment_number: nil, actual_ship_date: nil, tracking_number: nil, shipping_warehouse: '83'  }

    ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "'N' sales order line", test.recorder )
  end

  # Should be no salesorder lines at this time
  def self.db_check_salesorder_line_new( test, order )
    # Check sales order lines, shouldn't be there
    sql_cmd = <<EOF
SELECT *
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
 WHERE h.interface_header_id = l.interface_header_id AND
       order_number = #{order}
EOF
    ValidateOracleUtils.record_does_not_exist(test.odb_ro, sql_cmd, 'sales order line records', test.recorder )
  end

  def self.db_check_salesorder_payment_giftcertificate( test, order )
    sql_cmd = "SELECT error_message FROM xxmc.xxmc_salesorder_payments_v2 WHERE order_number = #{order}"
    checks = { error_message: nil }
    ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "sales order gift certificate payments", test.recorder )
  end

  def self.db_check_salesorder_payment_invoiced( test, order )
    sql_cmd = "SELECT error_message FROM xxmc.xxmc_salesorder_payments_v2 WHERE order_number = #{order}"
    checks = { error_message: nil }
    ValidateOracleUtils.record_check(test.odb_ro, sql_cmd, checks, "sales order payments", test.recorder )
  end

  # The check for sales order payments after canceled should come up empty
  def self.db_check_salesorder_payment_canceled( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_payments_v2 WHERE order_number = #{order}"
    ValidateOracleUtils.record_does_not_exist(test.odb_ro, sql_cmd, 'sales order payment records', test.recorder )
  end

  # The check for sales order payments after booked should come up empty
  def self.db_check_salesorder_payment_booked( test, order )
    sql_cmd = "SELECT * FROM xxmc.xxmc_salesorder_payments_v2 WHERE order_number = #{order}"
    ValidateOracleUtils.record_does_not_exist(test.odb_ro, sql_cmd, 'sales order payment records', test.recorder )
  end

  # The check for sales order payments after new order creation is currently the same as booked, but this will probably change
  def self.db_check_salesorder_payment_new( test, order )
    self.db_check_salesorder_payment_booked( test, order )
  end

  # The check for customer details after booked or gift certificates
  def self.db_check_customer_detail( test, order )
    # We need the ecomm order account id field to find the proper oracle records
    # Get the order account_id to cross reference customer details
    edb_order = QAEcommQuery.get_row( test.edb_ro, order, 'order', test.recorder )
    return 1 unless edb_order

    # Get the order shipping/billing addresses
    address = QAEcommQuery.get_array( test.edb_ro, order, 'addresses', test.recorder ).first
    return 1 unless address

    sql_cmd = <<EOF
SELECT c.interface_header_id, c.action, c.status, c.error_message, c.customer_class, c.address4, c.payment_term, c.billable_flag, c.shipable_flag,
       CASE WHEN c.billable_flag = 'Y' THEN 'Billing' ELSE 'Shipping' END AS test_label
  FROM xxmc.xxmc_customer_details_v2 c, xxmc.xxmc_salesorder_headers_v2 h
 WHERE h.order_number = #{order} AND
       h.action in ('N', 'GC') AND
       h.interface_header_id = c.interface_header_id AND
       c.customer_number = #{edb_order[:account_id]}
EOF

    warnings = { action: 'I', status: 'NEW' }

    checks = { error_message: nil, customer_class: 'CONSUMER',
               address4: nil, payment_term: 'IMMEDIATE' }

    ValidateOracleUtils.record_validate(test.odb_ro, sql_cmd, checks, warnings, 'customer details', test.recorder )
  end

  # Check if xxmc.t_al_host_order_master tables exist
  def self.db_t_al_host_exists( test, order )
    odb = test.odb_ro
    odb.exec( "SELECT * FROM xxmc.t_al_host_order_master WHERE ORDER_NUMBER = #{order}" ).fetch ? true : false
  end

  def self.db_t_al_host_poll( test )
    QAOperations.poll( test ) { |o| self.db_t_al_host_exists( test, o ) }
  end
end
