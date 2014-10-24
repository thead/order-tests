#!/usr/bin/env ruby

#
# Given a list of orders, validate that the E-comm data matches corresponding Oracle data payments
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'ecomm_queries'
require 'compare_db_utils'

module CompareDBPayments
  def self.db_check( edb, odb, order, state, recorder = QALogger.new )
    case state
    when 'giftcertificate'
      action = 'GC'
    when 'invoiced'
      action = 'S'
    else
      return 1
    end

    # Get the payment record(s)
    edb_payments = QAEcommQuery.get_array( edb, order, 'payments', recorder )
    return 1 unless edb_payments


    error_count = 0
    edb_payments.each do |edb_payment|
      sql_cmd = <<EOF
SELECT payment_method,
       TO_CHAR(payment_method_applied, 'FM999990.00') AS payment_method_applied,
       CAST(FROM_TZ(CAST(payment_capture_date AS TIMESTAMP), 'America/Los_Angeles') AT TIME ZONE 'UTC' AS DATE) AS payment_capture_date_utc,
       payment_method_id AS test_label
  FROM xxmc.xxmc_salesorder_headers_v2 h, xxmc.xxmc_salesorder_payments_v2 p
 WHERE h.order_number = #{order} AND p.order_number = #{order} AND
       h.interface_header_id = p.interface_header_id AND
       h.action = '#{action}' AND p.status = 'NEW' AND
       p.payment_method_id = '#{edb_payment[:payment_method_id]}'
EOF

      computed_method = case edb_payment[:payment_type]
                        when /Paypal/
                          'PAYPAL'
                        when /CreditCard/
                          'CC'
                        when /StoreCredit/
                          'STORECREDIT'
                        else
                          'UNKNOWN'
                        end

      computed_payment = "%.2f" % (edb_payment[:payment_amount].to_f / 100)

      checks = {
        payment_method:           { value: computed_method,               label: 'computed type field' },
        payment_method_applied:   { value: computed_payment,              label: 'transaction amount field' },
        payment_capture_date_utc: { value: edb_payment[:payment_created], label: 'price field' }
      }

      error_count += CompareDBUtils.record_check(odb, sql_cmd, checks, "sales order payment line", recorder )
    end

    error_count
  end
end
