#!/usr/bin/env ruby

#
# Given a list of orders, create oracle shipping records
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'manual_operations'

module CreateOracleShipments
  # Manually validate shipments in Oracle
  def self.manual_process( test, skip = nil )
    ManualOperations.manual_check( test, 'HJ wave/pick/sort/ship', skip )
  end

  # Requires xxmc.t_al_order_master and xxmc.t_al_order_detail records
  def self.db_add_all( test, options = 'None', options_line = nil )
    test.data.reduce(0) do |total_error_count, order|
      error_count = self.db_add( test.odb_rw, order, options, options_line, test.recorder )
      test.recorder.log_result( error_count == 0, "creating a shipped status in Oracle DB for #{order}" )
      total_error_count + error_count
    end
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.db_add_fraud_all( test )
    self.db_add_all( test, 'Fraud' )
  end

  def self.db_add_scratch_all( test )
    self.db_add_all( test, 'Scratch' )
  end

  def self.db_add_scratch_first_all( test )
    self.db_add_all( test, 'Scratch', 1 )
  end

  def self.db_add_cancel_all( test )
    self.db_add_all( test, 'Cancel' )
  end

  def self.db_add_cancel_first_all( test )
    self.db_add_all( test, 'Cancel', 1 )
  end

  # Add shipemnt master/detail records for one order
  def self.db_add( odb, order, options, options_line, recorder = QALogger.new )
    if options_line
      line_number_filter = "AND line_number = #{options_line}"
    else
      line_number_filter = ''
    end

    sql_master_cmd = <<EOF
INSERT INTO xxmc.t_al_host_shipment_master
            ( shipment_id, host_group_id, transaction_code, order_number, display_order_number,
              load_id, pro_number, seal_number, carrier_code, status, split_status, delivery_sap,
              total_weight, total_volume, user_id, wh_id, client_code, record_create_date,
              processing_status, fraud_cancellation, error_message )
     SELECT 666, 'FAKE-HOST-GROUP-ID-#{order}', 340, order_number, display_order_number,
            load_id, pro_number, '12x10x5', 'Baggable - Multi', 'COMPLETE', 'NOSPLIT', NULL,
            1, 2, 'AutoShip', wh_id, NULL, earliest_ship_date,
            'NEW', 'N', NULL
       FROM xxmc.t_al_host_order_master
      WHERE order_number = #{order} AND
            order_number NOT IN (SELECT order_number FROM xxmc.t_al_host_shipment_master)
EOF
    sql_detail_cmd = <<EOF
INSERT INTO xxmc.t_al_host_shipment_detail
            ( shipment_detail_id, shipment_id, host_group_id, line_number, item_number,
              display_item_number, lot_number, quantity_shipped, hu_id, delivery_sap, user_id,
              wh_id, client_code, record_create_date, uom, tracking_number, order_number,
              display_order_number, processing_status )
     SELECT 666, 666, 'FAKE-HOST-GROUP-ID-#{order}', line_number, item_number,
            display_item_number, lot_number, qty, 'FAKE-CARTON', NULL, 'AutoShip',
            wh_id, client_code, record_create_date, 'EA', 1234567890, order_number,
            display_order_number, 'NEW'
       FROM xxmc.t_al_host_order_detail
      WHERE order_number = #{order} AND
            order_number NOT IN (SELECT order_number FROM xxmc.t_al_host_shipment_detail)
EOF
    sql_upload_cmd = <<EOF
INSERT INTO xxmc.t_host_upload_notify_intf
            ( host_group_id, table_name, createdon, status, processstart, processend )
     SELECT 'FAKE-HOST-GROUP-ID-#{order}', 'T_AL_HOST_SHIPMENT_MASTER', record_create_date, 'NEW', NULL, NULL
       FROM xxmc.t_al_host_order_master
      WHERE order_number = #{order}
EOF

    sql_cancel_for_fraud_cmd = <<EOF
UPDATE xxmc.t_al_host_shipment_master
   SET fraud_cancellation = 'Y'
 WHERE order_number = #{order}
EOF

    sql_cancel_cmd = <<EOF
UPDATE xxmc.t_al_host_shipment_detail
   SET quantity_shipped = 0, tracking_number = NULL
 WHERE order_number = #{order} #{line_number_filter}
EOF

    sql_scratch_cancel_cmd = "#{sql_cancel_cmd} AND quantity_shipped = 1"
    sql_scratch_cmd = <<EOF
UPDATE xxmc.t_al_host_shipment_detail
   SET quantity_shipped = quantity_shipped - 1
 WHERE order_number = #{order} #{line_number_filter} AND quantity_shipped > 1
EOF

    recorder.logger.debug "Oracle SQL for creating a shipping master record for #{order}:\n#{sql_master_cmd}"
    recorder.logger.debug "Oracle SQL for creating shipping detail record(s) for #{order}:\n#{sql_detail_cmd}"

    record_count = odb.exec( sql_master_cmd )
    recorder.logger.debug "Oracle SQL record insert count for shipping master table for #{order} is #{record_count}"
    error_count = record_count == 1 ? 0 : 1
    return error_count unless error_count == 0

    record_count = odb.exec( sql_detail_cmd )
    recorder.logger.debug "Oracle SQL record insert count for shipping detail table for #{order} is #{record_count}"
    error_count += record_count > 0 ? 0 : 1
    return error_count unless error_count == 0

    record_count = odb.exec( sql_upload_cmd )
    recorder.logger.debug "Oracle SQL record insert count for upload notify table for #{order} is #{record_count}"
    error_count += record_count == 1 ? 0 : 1

    # Adjust detail sql based on scratch or cancel requests
    case options
    when 'Scratch'
      odb.exec( sql_scratch_cancel_cmd )
      odb.exec( sql_scratch_cmd )
    when 'Cancel'
      odb.exec( sql_cancel_cmd )
    when 'Fraud'
      odb.exec( sql_cancel_for_fraud_cmd )
    end

    # commit and return error count
    odb.exec('commit')
    error_count
  end
end
