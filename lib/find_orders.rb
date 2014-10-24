#!/usr/bin/env ruby

#
# Support finding orders in a certain state
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'ecomm_queries'
require 'oracle_queries'

module FindOrders
  def self.find( test, type )
    order_data = []
    case type
    when 'latest item order', 'latest gift certificate'
      found_orders =  QAEcommQuery.get_array( test.edb_ro, test.repeat, type, test.recorder )
      found_orders.each { |record|
        order_data << record[:ORDER_NUMBER]
      } if found_orders
    when 'latest shipped order', 'latest fraud canceled order', 'waiting to ship day old order'
      found_orders = QAOracleQuery.get_array( test.odb_ro, test.repeat, type, test.recorder )
      found_orders.each { |record|
        order_data << record['ORDER_NUMBER']
      } if found_orders
    else
      test.logger.error "Unsupported type for FindOrders.find: #{type}"
      return 1
    end

    if order_data.any?
      test.data.concat( order_data )
    else
      test.logger.info "No appropriate order found, exiting without error"
      test.exit = true
    end
    return 0
  end

  def self.new( test )
    self.find( test, 'latest item order' )
  end

  def self.new_gc( test )
    self.find( test, 'latest gift certificate' )
  end

  def self.shipped( test )
    self.find( test, 'latest shipped order' )
  end

  def self.fraud_canceled( test )
    self.find( test, 'latest fraud canceled order' )
  end

  def self.unshipped( test )
    self.find( test, 'waiting to ship day old order' )
  end
end
