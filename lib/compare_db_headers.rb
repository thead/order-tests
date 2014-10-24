
#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'ecomm_queries'
require 'compare_db_utils'

module CompareDBHeaders
  def self.db_check( edb, odb, order, state, recorder = QALogger.new )
    case state
    when 'booked'
      action = 'N'
    when 'giftcertificate'
      action = 'GC'
    when 'invoiced'
      action = 'S'
    when 'canceled'
      action = 'C'
    else
      return 1
    end

    # Get the order record
    edb_order = QAEcommQuery.get_row( edb, order, 'order', recorder )
    return 1 unless edb_order

    # Get order address records
    edb_addresses = QAEcommQuery.get_array( edb, order, 'addresses', recorder )
    return 1 unless edb_addresses

    sql_cmd = <<EOF
SELECT orig_order_number,
       CAST(FROM_TZ(CAST(creation_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS creation_date_utc,
       CAST(FROM_TZ(CAST(ordered_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS ordered_date_utc,
       CAST(FROM_TZ(CAST(last_update_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS last_update_date_utc,
       CAST(customer_number AS integer) AS customer_number_int,
       ship_to_site_unique_name, bill_to_site_unique_name,
       gift_order, pgh_office_order, shipping_method
  FROM xxmc.xxmc_salesorder_headers_v2
 WHERE order_number = #{order} AND action = '#{action}'
EOF

    # Compute the sha512 hash for concatinated order/address data
    computed_bill_name = computed_ship_name = nil
    edb_addresses.each do |address|
      computed_ship_name = CompareDBUtils.compute_sha512_address( edb_order, address, recorder ) if address[:type] == 'ShippingAddress'
      computed_bill_name = CompareDBUtils.compute_sha512_address( edb_order, address, recorder ) if address[:type] == 'BillingAddress'
    end

    correct_orig_order_number = CompareDBUtils.get_root_order_parent(edb, order, edb_order[:parent_order_id], recorder)
    converted_gift_order = (edb_order[:is_gift] == 0) ? 'N' : 'Y'
    converted_pgh_office_order = edb_order[:is_pgh_fc_delivery] ? 'Y' : 'N'

    warnings = {
      last_update_date_utc:     { value: edb_order[:updated_at],           label: 'updated_at field' }
    }

    checks = {
      orig_order_number:        { value: correct_orig_order_number,        label: 'parent_order_id field'},
      creation_date_utc:        { value: edb_order[:created_at],           label: 'created_at field' },
      ordered_date_utc:         { value: edb_order[:created_at],           label: 'created_at field' },
      customer_number_int:      { value: edb_order[:account_id].to_i,      label: 'account_id field' },
      ship_to_site_unique_name: { value: computed_ship_name,               label: 'computed ship name based on shipping address' },
      bill_to_site_unique_name: { value: computed_bill_name,               label: 'computed bill name based on billing address' },
      gift_order:               { value: converted_gift_order,             label: 'converted is_gift field' },
      pgh_office_order:         { value: converted_pgh_office_order,       label: 'converted is_pgh_fc_delivery field' },
    }
    checks[:shipping_method] =  { value: edb_order[:shipping_method_code], label: 'shipping_method_code field' } unless state == 'giftcertificate'

    CompareDBUtils.record_validate(odb, sql_cmd, checks, warnings, "'#{action}' sales order headers", recorder )
  end
end
