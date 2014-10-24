#!/usr/bin/env ruby

#
# Given a list of orders, validate that the Higjump system has the correct data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'manual_operations'

module ValidateHJOrders
  # Manually validate orders in Ecomm
  def self.manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'High Jump order DB', manual )
  end

  # Check if hj order has been downloaded
  def self.is_downloaded( test, order )
    hjdb = test.hjdb_ro
    result = hjdb.execute("SELECT * FROM t_al_host_order_master WHERE order_number = #{order};")
    result.each
    result.affected_rows > 0
  end

  def self.is_downloaded_poll( test )
    QAOperations.poll( test ) { |o| self.is_downloaded( test, o ) }
  end
end
