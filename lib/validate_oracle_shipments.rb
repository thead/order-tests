#!/usr/bin/env ruby

#
# Given a list of orders, validate that the Oracle system has the correct shipment data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'manual_operations'
require 'validate_oracle_utils'
require 'validate_ecomm_orders'
require 'oracle_queries'

module ValidateOracleShipments
  # Manually validate shipments in Oracle
  def self.manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'Oracle shipment DB', manual )
  end

  # We support 2 testing states at present:
  #   agile ship: Check oracle shipping tables after agile ships an order
  #   uniblab ship: Check oracle shipping tables after uniblab ships an order

  def self.db_check_all_state( test, state )
    test.data.reduce(0) do |error_count, order|
      test.logger.info "Checking #{state} shipped status in Oracle DB for #{order}"
      error_count + test.recorder.indent_logging { self.db_check_shipments( test.odb_ro, order, state, test.recorder ) }
    end
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.db_check_agile_all( test )
    self.db_check_all_state( test, 'agile' )
  end

  def self.db_check_uniblab_all( test )
    self.db_check_all_state( test, 'uniblab' )
  end

  # Lower level method does not require QATestEnv, can be invoked independent of those objects
  # optionally provide a recorder to exploit logging/debugging support

  def self.db_check_shipments( odb, order, state, recorder = QALogger.new )
    sql_master_cmd = "SELECT * FROM xxmc.t_al_host_shipment_master WHERE order_number = #{order}"
    sql_detail_cmd = "SELECT * FROM xxmc.t_al_host_shipment_detail WHERE order_number = #{order}"
    sql_upload_cmd = <<EOF
SELECT u.*
  FROM xxmc.t_host_upload_notify_intf u,xxmc.t_al_host_shipment_master m
 WHERE u.host_group_id = m.host_group_id AND order_number = #{order}
EOF
    case state
    when 'agile'
      checks = upload_checks = []
      warnings = { processing_status: 'NEW' }
      upload_warnings = { status: 'NEW' }
    when 'uniblab'
      checks = { processing_status: 'PROCESSED' }
      upload_checks = { status: 'COMPLETED' }
      warnings = upload_warnings = []
    else
      return nil
    end

    error_count = ValidateOracleUtils.record_validate(odb, sql_master_cmd, checks, warnings, "shipment master record", recorder )
    error_count += ValidateOracleUtils.record_validate(odb, sql_detail_cmd, checks, warnings, "shipment detail record", recorder )
    error_count += ValidateOracleUtils.record_validate(odb, sql_upload_cmd, upload_checks, upload_warnings, "upload notify record", recorder )

    return error_count
  end

  #Check if xxmc.t_al_host_shipment_master tables exist
  def self.db_t_al_host_exists(test, order )
    odb = test.odb_ro
    result = odb.exec( "SELECT * FROM xxmc.t_al_host_shipment_master WHERE ORDER_NUMBER = #{order}" ).fetch
    return result ? true : false
  end

  # default wait is 60 minutes
  def self.db_t_al_host_poll( test, wait_cycles = 60 )
    QAOperations.poll( test, wait_cycles ) { |o| self.db_t_al_host_exists( test, o ) }
  end

  # wait is 7 days
  def self.db_t_al_host_longpoll( test )
    self.db_t_al_host_poll( test, 10080 )
  end

  def self.shipment_master_processed( test, order )
    return QAOracleQuery.get_field( test.odb_ro, order, 'shipment master processing status', test.recorder ) == 'PROCESSED'
  end

  def self.shipment_master_processed_poll( test )
    QAOperations.poll( test ) { |o| self.shipment_master_processed( test, o ) }
  end

  def self.is_shipped( test, order )
    return QAOracleQuery.get_field( test.odb_ro, order, 'shipment master processing status', test.recorder ) != 'NEW'
  end

  def self.is_shipped_poll( test )
    QAOperations.poll( test ) { |o| self.is_shipped( test, o ) && ValidateEcommOrders.is_shipped( test, o ) }
  end
end
