#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle customer data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'ecomm_queries'
require 'compare_db_utils'

module CompareDBCustomers
  def self.db_check( edb, odb, order, state, recorder = QALogger.new )
    case state
    when 'giftcertificate'
      action = 'GC'
    when 'booked'
      action = 'N'
    end
    # Get the order record
    edb_order = QAEcommQuery.get_row( edb, order, 'order', recorder )
    return 1 unless edb_order

    # Get the order shipping/billing addresses
    edb_addresses = QAEcommQuery.get_array( edb, order, 'addresses', recorder )
    return 1 unless edb_addresses

    # Get the order account
    edb_account = QAEcommQuery.get_row( edb, order, 'account', recorder )
    return 1 unless edb_account

    # Compute if the billing and shipping addresses are the same
    bill_ship_both = CompareDBUtils.bill_ship_equal?( edb_order, edb_addresses, recorder )

    # Check for correct number of address records before looping
    error_count = 0
    if edb_addresses.length != 2
      recorder.logger.error "Did not find 2 order addresses (shipping/billing) from ecomm"
      error_count += 1
    end

    # Lets loop through each address record, comparing to oracle customer detals
    edb_addresses.each do |address|
      # Without the sha512 hash, we can not tell which oracle customer record
      # is shipping and which is billing
      address_name = CompareDBUtils.compute_sha512_address( edb_order, address, recorder )

      # Compare Oracle customer details data with Ecomm
      # NOTE: Probably will need to cross-compare with salesorder headers
      # to validate the address_name at some point. Manually verified for now
      sql_cmd = <<EOF
SELECT customer_name, address1, address2, address3,
       city, region, zip_code, country_code,
       CAST(FROM_TZ(CAST(last_updated AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS last_update_utc,
       CAST(FROM_TZ(CAST(c.creation_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS creation_date_utc
  FROM xxmc.xxmc_customer_details_v2 c, xxmc.xxmc_salesorder_headers_v2 h
 WHERE order_number = #{order} AND
       h.action = '#{action}' AND
       h.interface_header_id = c.interface_header_id AND
       c.address_name = '#{address_name}' AND
       c.customer_number = #{edb_order[:account_id]} AND
       billable_flag = 'Y' AND shipable_flag = 'Y'
EOF

      computed_name = "#{address[:firstname]} #{address[:lastname]}"
      computed_address = (address[:street_2] == "") ? nil : address[:street_2]
      computed_zip = (address[:postal_code] and address[:postal_code] != '') ? address[:postal_code] : '00000'

      warnings = []
      checks = {
        customer_name: { value: edb_account[:login],    label: 'login field in the account table' },
        address1:      { value: computed_name,          label: 'concatination of first and last names in the address table' },
        address2:      { value: address[:street_1],     label: 'street_1 field in the address table' },
        address3:      { value: computed_address,       label: 'street_2 field in the address table' },
        city:          { value: address[:city],         label: 'city field in the address table' },
        region:        { value: address[:abbreviation], label: 'abbreviation for the region id in the address table' },
        zip_code:      { value: computed_zip,           label: 'computed zip code from postal code in the address table' },
        country_code:  { value: address[:alpha_2_code], label: 'alpha 2 code for the country id in the address table' }
      }

      # If we have a combined billing/shipping customer details record then
      # skip date stamp checks against the Billing Address (when combined, time stamps are taken from Shipping Address)
      unless bill_ship_both and (address[:type] == 'BillingAddress')
        warnings = {
          last_update_utc: { value: address[:updated_at], label: 'updated_at field in the address table' },
          creation_date_utc: { value: address[:created_at], label: 'created_at field in the address table' }
        }
      end

      error_count += CompareDBUtils.record_validate(odb, sql_cmd, checks, warnings, "customer details (#{address[:type]})", recorder )
    end

    error_count
  end
end
