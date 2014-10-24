
#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle data lines
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'ecomm_queries'
require 'compare_db_utils'
require 'validate_oracle_utils'

module CompareDBLines
  def self.db_check( edb, odb, order, state, recorder = QALogger.new )
    case state
    when 'booked'
      action = ['N']
    when 'giftcertificate'
      action = ['N','GC']
    when 'invoiced'
      action = ['S','C','U']
    when 'canceled'
      action = ['C']
    else
      return 1
    end

    # Get the order record
    edb_order = QAEcommQuery.get_row( edb, order, 'order', recorder )
    return 1 unless edb_order

    # Get the order line items
    if state == 'giftcertificate'
      edb_items = QAEcommQuery.get_array( edb, order, 'giftcertificates', recorder )
    else
      edb_items = QAEcommQuery.get_array( edb, order, 'items', recorder )
      # edb_items_original = QAEcommQuery.get_array( edb, order, 'new items', recorder )
    end
    return 1 unless edb_items


    # Compare Oracle sales order lines data with Ecomm in line number order
    error_count = 0
    edb_items.each do |edb_item|

      sql_cmd = <<EOF
  SELECT order_line_type, sku, ordered_quantity, l.action,
         CAST(FROM_TZ(CAST(l.last_update_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS last_update_date_utc,
         CAST(FROM_TZ(CAST(schedule_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS schedule_ship_date_utc,
         CAST(FROM_TZ(CAST(promise_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS promise_date_utc,
         CAST(FROM_TZ(CAST(request_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS request_date_utc,
         CAST(FROM_TZ(CAST(actual_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS actual_ship_date_utc,
         TO_CHAR(unit_selling_price, 'FM999990.00') AS unit_selling_price,
         TO_CHAR(discount_value, 'FM999990.00') AS discount_value,
          discount_name, final_sale , shipped_quantity, tracking_number,
         CAST(line_number AS INT) AS test_label
    FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
   WHERE h.interface_header_id = l.interface_header_id AND
         order_number = #{order} AND
         h.action IN ('#{action.join("','")}') AND
         l.action IN ('#{action.join("','")}') AND
         line_number = #{edb_item[:line_number]}
EOF

      if state == 'giftcertificate'
        converted_price = "%.2f" % edb_item[:amount]
      else
        converted_price = "%.2f" % edb_item[:price]
      end

      if state == 'booked'
        computed_ship_quantity = nil
      elsif state == 'canceled'
        computed_ship_quantity = 0
      elsif state == 'giftcertificate'
        computed_ship_quantity = 1
      else
        computed_ship_quantity = edb_item[:quantity] - edb_item[:cancel_quantity]
      end

      # Does not yet reflect updated discounts
      computed_action = if state == 'booked' || state == 'giftcertificate'
                          'N'
                        elsif state == 'canceled' || computed_ship_quantity == 0
                          'C'
                        elsif edb_item[:cancel_quantity] > 0
                          'U'
                        else
                          'S'
                        end

      warnings = {
        last_update_date_utc:   { value: edb_item[:updated_at],  label: 'updated_at field' }
      }

      checks = {
        schedule_ship_date_utc: { value: edb_order[:created_at], label: 'order created_at field' },
        promise_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
        request_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
        unit_selling_price:     { value: converted_price,        label: 'price field' },
        action:                 { value: computed_action,        label: 'computed action value' }
      }

      if state == 'giftcertificate'
        checks[:actual_ship_date_utc] = { value: edb_item[:actual_ship_date], label: 'minumum created_at order_shipment field' }
      else
        correct_type = ( edb_item[:price] == 0 ? 'SO No Invoice Line' : 'SO Invoice Line' )
        correct_final_sale = ( edb_item[:is_returnable] ? 'N' : 'Y' )
        correct_discount_value = edb_item[:amount] ? edb_item[:price] - edb_item[:amount] : 0
        correct_discount_value = 0 if correct_discount_value.abs < 0.01
        converted_discount = "%.2f" % correct_discount_value

        # Get discount name, can be nil
        edb_discount_name = QAEcommQuery.get_field( edb, order, 'discount name', recorder )

        if computed_ship_quantity == 0
          computed_discount_name = nil
        else
          computed_discount_name   = edb_discount_name
        end

        checks[:order_line_type]  = { value: correct_type,           label: 'price field based' }
        checks[:sku]              = { value: edb_item[:upc],         label: 'upc field' }
        checks[:ordered_quantity] = { value: edb_item[:quantity],    label: 'quantity field' }
        checks[:discount_value]   = { value: converted_discount,     label: 'item_discounted_prices amount field' }
        checks[:discount_name]    = { value: computed_discount_name, label: 'discount and coupon fields' }
        checks[:final_sale]       = { value: correct_final_sale,     label: 'is_returnable field' }
        checks[:shipped_quantity] = { value: computed_ship_quantity, label: 'computed ship quantity' }

        if state == 'invoiced'
          edb_actual_ship_date = QAEcommQuery.get_field( edb, order, 'shipment date', recorder )
          edb_tracking_number  = QAEcommQuery.get_field( edb, order, 'tracking number', recorder )

          if computed_ship_quantity == 0
            computed_tracking_number = nil
          else
            computed_tracking_number = edb_tracking_number
          end

          checks[:actual_ship_date_utc] = { value: edb_actual_ship_date,     label: 'shipped_at field' }
          checks[:tracking_number]      = { value: computed_tracking_number, label: 'tracking_number field' }
        end

      end

      error_count += CompareDBUtils.record_validate(odb, sql_cmd, checks, warnings, "'#{action.join}' sales order line", recorder )
    end

    error_count
  end

  def self.db_check_salestax( edb, odb, order, recorder = QALogger.new )
    # Get the order record
    edb_order = QAEcommQuery.get_row( edb, order, 'order', recorder )
    return 1 unless edb_order

    edb_items = QAEcommQuery.get_array( edb, order, 'items', recorder )
    return 1 unless edb_items

    edb_actual_ship_date = QAEcommQuery.get_field( edb, order, 'shipment date', recorder )
    edb_tracking_number  = QAEcommQuery.get_field( edb, order, 'tracking number', recorder )

    sql_cmd = <<EOF
  SELECT line_number, order_line_type, tracking_number,
         CAST(FROM_TZ(CAST(l.last_update_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS last_update_date_utc,
         CAST(FROM_TZ(CAST(schedule_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS schedule_ship_date_utc,
         CAST(FROM_TZ(CAST(promise_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS promise_date_utc,
         CAST(FROM_TZ(CAST(request_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS request_date_utc,
         CAST(FROM_TZ(CAST(actual_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS actual_ship_date_utc,
         TO_CHAR(unit_selling_price, 'FM999990.00') AS unit_selling_price,
         CAST(line_number AS INT) AS test_label
    FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
   WHERE order_number = #{order} AND
         h.interface_header_id = l.interface_header_id AND
         h.action = 'S' AND l.action = 'N' AND
         l.sku = 'SALESTAX'
EOF

    # No tax, no tax line
    if edb_order[:tax_amt] == 0
      return ValidateOracleUtils.record_does_not_exist(odb, sql_cmd, 'sales order tax line record', recorder )
    end

    converted_price = "%.2f" % edb_order[:tax_amt]
    computed_line = edb_items.last[:line_number] + 1
    computed_line += 1 if edb_order[:tax_amt] != 0

    warnings = {
      last_update_date_utc:   { value: edb_order[:updated_at], label: 'updated_at field' }
    }

    checks = {
      line_number:            { value: computed_line,          label: 'max line number' },
      order_line_type:        { value: 'SO Invoice Only Line', label: 'constant SO Invoice Only Line' },
      schedule_ship_date_utc: { value: edb_order[:created_at], label: 'order created_at field' },
      promise_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
      request_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
      unit_selling_price:     { value: converted_price,        label: 'price field' },
      actual_ship_date_utc:   { value: edb_actual_ship_date,   label: 'shipped_at field' },
      tracking_number:        { value: edb_tracking_number,    label: 'tracking_number field' }
    }

    CompareDBUtils.record_validate(odb, sql_cmd, checks, warnings, "sales order tax line", recorder )
  end

  def self.db_check_shipping( edb, odb, order, recorder = QALogger.new )
    # Get the order record
    edb_order = QAEcommQuery.get_row( edb, order, 'order', recorder )
    return 1 unless edb_order

    edb_items = QAEcommQuery.get_array( edb, order, 'items', recorder )
    return 1 unless edb_items

    edb_actual_ship_date = QAEcommQuery.get_field( edb, order, 'shipment date', recorder )
    edb_tracking_number  = QAEcommQuery.get_field( edb, order, 'tracking number', recorder )

    sql_cmd = <<EOF
  SELECT line_number, order_line_type, tracking_number,
         CAST(FROM_TZ(CAST(l.last_update_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS last_update_date_utc,
         CAST(FROM_TZ(CAST(schedule_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS schedule_ship_date_utc,
         CAST(FROM_TZ(CAST(promise_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS promise_date_utc,
         CAST(FROM_TZ(CAST(request_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS request_date_utc,
         CAST(FROM_TZ(CAST(actual_ship_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS actual_ship_date_utc,
         TO_CHAR(unit_selling_price, 'FM999990.00') AS unit_selling_price,
         CAST(line_number AS INT) AS test_label
    FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_lines_v2 l
   WHERE order_number = #{order} AND
         h.interface_header_id = l.interface_header_id AND
         h.action = 'S' AND l.action = 'N' AND
         l.sku = 'SHIPPING'
EOF
    converted_price = "%.2f" % edb_order[:shipping_cost]
    computed_line = edb_items.last[:line_number] + 1
    computed_line_type = 'SO Invoice Only Line'

    warnings = {
      last_update_date_utc:   { value: edb_order[:updated_at], label: 'updated_at field' }
    }

    checks = {
      line_number:            { value: computed_line,          label: 'max line number except salestax' },
      schedule_ship_date_utc: { value: edb_order[:created_at], label: 'order created_at field' },
      promise_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
      request_date_utc:       { value: edb_order[:created_at], label: 'order created_at field' },
      unit_selling_price:     { value: converted_price,        label: 'price field' },
      order_line_type:        { value: computed_line_type,     label: 'computed based on price field' },
      actual_ship_date_utc:   { value: edb_actual_ship_date,   label: 'shipped_at field' },
      tracking_number:        { value: edb_tracking_number,    label: 'tracking_number field' }
    }

    CompareDBUtils.record_validate(odb, sql_cmd, checks, warnings, "sales order shipping line", recorder )
  end
end
