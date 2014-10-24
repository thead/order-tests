#!/usr/bin/env ruby

#
# Query E-comm data
#

$LOAD_PATH << File.expand_path('..', __FILE__)

module QAEcommQuery
  # Return data field or nil
  def self.get_field(edb, in_data, label, recorder = QALogger.new)
    case label
    when 'order book time'
      edb_query_str = "SELECT last_viewed_in_admin_at AS data FROM orders WHERE id = #{in_data}"
    when 'order parent'
      edb_query_str = "SELECT parent_order_id AS data FROM orders WHERE id = #{in_data}"
    when 'is capture complete'
      edb_query_str = "SELECT is_capture_complete AS data FROM orders WHERE id = #{in_data}"
    when 'store credit'
      edb_query_str = "SELECT sum(amount)/100 AS data FROM payment_methods WHERE payment_methods.order_id = #{in_data} AND source_type = 'StoreCredit'"
    when 'sku'
      edb_query_str = "SELECT sku AS data FROM variants WHERE upc = #{in_data}"
    when 'upc'
      edb_query_str = "SELECT upc AS data FROM variants WHERE sku = '#{in_data}'"
    when 'discount name'
      edb_query_str = <<EOF
   SELECT COALESCE(campaign.name, coupon.name, '') AS data
     FROM discounts d
LEFT JOIN coupons coupon ON coupon.id = d.coupon_id
LEFT JOIN coupon_campaigns campaign ON coupon.campaign_id = campaign.id
    WHERE d.state='applied' AND
         d.order_id=#{in_data}
EOF
    when 'shipment date'
      edb_query_str = <<EOF
  SELECT shipped_at AS data
    FROM order_shipments
   WHERE order_id=#{in_data}
ORDER BY shipment_number DESC
   LIMIT 1
EOF
    when 'tracking number'
      edb_query_str = <<EOF
  SELECT tracking_number AS data
    FROM order_shipments
   WHERE order_id=#{in_data} AND
         tracking_number IS NOT null AND
         tracking_number <> ''
ORDER BY shipment_number DESC
   LIMIT 1
EOF
    else
      recorder.logger.error "get_field received unknown label #{label}"
      return nil
    end
    recorder.logger.debug "Ecomm #{label} SQL for #{in_data}:\n#{edb_query_str}"

    edb_row = edb[ edb_query_str ].first
    data = edb_row ? edb_row[:data] : nil
    recorder.logger.debug "Ecomm #{label} data for #{in_data}: #{data}"

    return data
  end

  # Return data row or nil
  def self.get_row( edb, in_data, label, recorder = QALogger.new )
    case label
    when 'order'
      # We don't actually have order_shipments proper in v2 yet
      # edb_query_str = "SELECT * FROM orders, order_shipments WHERE order_id = #{in_data} AND orders.id = order_id"
      edb_query_str = "SELECT * FROM orders WHERE id = #{in_data}"
    when 'order+state'
      edb_query_str = <<EOF
   SELECT o.*, i.name as internal_state, f.name as finance_state
     FROM orders o
LEFT JOIN internal_states i ON i.id = o.internal_state_id
LEFT JOIN finance_states f  ON f.id = o.finance_state_id
    WHERE o.id = #{in_data}
EOF
    when 'payment transaction'
      # Get brain tree payment transaction reference number for order (if they exist)
      edb_query_str = <<EOF
SELECT reference FROM payment_methods, payment_transactions
 WHERE payment_methods.id = payment_method_id AND
       payment_methods.order_id = #{in_data} AND
       action = 'capture' AND
       source_type IS NULL
EOF
    when 'account'
      edb_query_str = "SELECT accounts.* FROM accounts,orders WHERE orders.id = #{in_data} AND orders.account_id = accounts.id"
    else
      recorder.logger.error "get_row received unknown label #{label}"
      return nil
    end
    recorder.logger.debug "Ecomm #{label} SQL:\n#{edb_query_str}"

    edb_row = edb[ edb_query_str ].first
    recorder.logger.debug "Ecomm #{label} data for #{in_data}: #{edb_row}"

    # If the Ecomm db data is not available, fail
    if (not edb_row) or edb_row.empty?
      recorder.logger.error "No Ecomm record found"
      return nil
    end
    return edb_row
  end

  # Return order items array or nil
  def self.get_array( edb, in_data, label, recorder = QALogger.new )
    case label
    when 'giftcertificates'
      edb_query_str = <<EOF
   SELECT gc.*, l.line_number, MIN(s.created_at) AS actual_ship_date
     FROM ( SELECT id, amount, created_at, updated_at
              FROM gift_certificates
             WHERE order_id = #{in_data} ) AS gc
LEFT JOIN line_items l ON l.owner_id = gc.id
LEFT JOIN order_shipments s ON s.order_id = #{in_data}
    WHERE l.owner_type = 'GiftCertificate'
 GROUP BY gc.id
 ORDER BY l.line_number
EOF
    when 'items'
      edb_query_str = <<EOF
   SELECT i.*, line_number, upc, is_returnable, amount, COALESCE( SUM(c.cancel_quantity), 0 ) AS cancel_quantity
     FROM ( SELECT id, owner_id, owner_type, variant_id, quantity, price, created_at, updated_at
              FROM items
             WHERE owner_id = #{in_data} AND
                   owner_type = 'Order'
             UNION
            SELECT id, owner_id, owner_type, variant_id, quantity, price, created_at, updated_at
              FROM promotional_items
             WHERE owner_id = #{in_data} AND
                   owner_type = 'Order' ) AS i
LEFT JOIN line_items l ON l.owner_id = i.id
LEFT JOIN variants v ON v.id = i.variant_id
LEFT JOIN products p ON p.id = v.product_id
LEFT JOIN item_discounted_prices d ON d.item_id = i.id
LEFT JOIN item_cancellations c ON i.id = c.item_id
    WHERE l.owner_type = 'Item' OR l.owner_type = 'PromotionalItem'
 GROUP BY i.id
 ORDER BY line_number
EOF
    when 'addresses'
      edb_query_str = <<EOF
SELECT addresses.*, abbreviation, alpha_2_code, DATE_FORMAT( addresses.created_at, "%Y-%m-%d %H:%i:%s" ) AS created_at_string
  FROM addresses,regions,countries WHERE addresses.region_id = regions.id AND
       regions.country_id = countries.id AND
       addressable_id = #{in_data} AND
       addressable_type = 'Order'
EOF
    when 'payments'
      edb_query_str = <<EOF
    SELECT pm.type AS payment_type,
           pt.amount AS payment_amount,
           pt.created_at AS payment_created,
           COALESCE(sc_by_source.root_store_credit_id, sc_by_source.id, pt.reference,0) AS payment_method_id
      FROM payment_methods pm
INNER JOIN payment_transactions pt
        ON pt.payment_method_id = pm.id
 LEFT JOIN store_credits sc_by_source
        ON ( sc_by_source.id = pm.source_id AND
             pm.source_type = 'StoreCredit' AND
             pm.type IN ( 'StoreCreditPaymentMethod', 'RefundStoreCreditPaymentMethod', 'GiftCertificateStoreCreditPaymentMethod', 'CustomerAppeasementStoreCreditPaymentMethod' ) AND
             ( pt.action = 'capture' OR pm.type IN ( 'CustomerAppeasementStoreCreditPaymentMethod', 'StoreCreditPaymentMethod' )))
     WHERE pt.action IN ('capture') AND pt.success = 1 AND pm.order_id = #{in_data}
EOF
    when 'shipments'
      edb_query_str = <<EOF
SELECT tracking_number, shipped_at
  FROM order_shipments
 WHERE order_id=#{in_data}
EOF
    when 'latest item order'
      edb_query_str = <<EOF
    SELECT DISTINCT orders.id AS ORDER_NUMBER
      FROM orders
INNER JOIN finance_states ON finance_states.id = orders.finance_state_id
 LEFT JOIN internal_states ON internal_states.id = orders.internal_state_id
 LEFT JOIN toggle_switches fulfillment_toggle ON fulfillment_toggle.name = 'order_fulfillment'
     WHERE finance_states.name = 'pending' AND
           shipping_method_code <> 'DNS' AND
           NOT fulfillment_toggle.activated AND
           state = 'pending' AND
           internal_state_id = 0 AND
           last_viewed_in_admin_at <= NOW()
  ORDER BY orders.created_at DESC LIMIT #{in_data}
EOF
    when 'latest gift certificate'
      edb_query_str = <<EOF
    SELECT DISTINCT orders.id AS ORDER_NUMBER
      FROM orders
INNER JOIN finance_states ON finance_states.id = orders.finance_state_id
 LEFT JOIN order_shipments ON order_shipments.order_id = orders.id
 LEFT JOIN payment_methods ON payment_methods.order_id = orders.id
     WHERE finance_states.name = 'pending' AND
           shipping_method_code = 'DNS' AND
           ( is_capture_complete = 1 OR payment_methods.id IS NULL ) AND
           order_shipments.id IS NOT NULL
  ORDER BY orders.created_at DESC LIMIT #{in_data}
EOF
    else
      recorder.logger.error "get_array received unknown label #{label}"
      return nil
    end
    recorder.logger.debug "Ecomm #{label} SQL:\n#{edb_query_str}"
    edb_rows = edb[ edb_query_str ].all
    recorder.logger.debug "Ecomm #{label} data for #{in_data}: #{edb_rows}"

    # If the Ecomm data is not available, bail
    if (not edb_rows) or (edb_rows.length == 0)
      recorder.logger.error "No Ecomm records found"
      return nil
    end
    return edb_rows
  end
end
