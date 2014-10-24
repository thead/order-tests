#!/usr/bin/env ruby

#
# Compare Higjump data to the Oracle data
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'
require 'manual_operations'

module CompareHJ
  # Manually validate orders in Ecomm
  def self.orders_manual_check( test, manual = nil )
    ManualOperations.manual_check( test, 'High Jump order DB data to Oracle order DB data', manual )
  end

  def self.db_check_order_all( test )
    error_count = 0
    test.data.each do |order|
      test.logger.info "Comparing Oracle/HJ DBs for order #{order}"
      order_error_count = test.recorder.indent_logging {
        self.db_check_order_master( test.odb_ro, test.hjdb_ro, order, test.recorder ) +
        self.db_check_order_detail( test.odb_ro, test.hjdb_ro, order, test.recorder )
      }
      test.recorder.log_result( order_error_count == 0, "comparision of Oracle/HJ DBs for order #{order}" )
      error_count += order_error_count
    end
    error_count
  end

  def self.db_check_order_master( odb, hjdb, order, recorder = QALogger.new )
    total_error_count = 0

    oracle_sql_query = "SELECT * FROM xxmc.t_al_host_order_master WHERE order_number = #{order}"
    recorder.logger.debug "Oracle SQL query is:\n#{oracle_sql_query}"

    cursor = odb.parse( oracle_sql_query )
    cursor.exec()
    while odb_record = cursor.fetch_hash()
      converted_record = self.key_lowercase( odb_record )
      converted_record['backorder'] = 'N' if converted_record['backorder'] == nil
      converted_record['ship_to_residential_flag'] = 'N' if converted_record['ship_to_residential_flag'] == nil
      converted_record['special_package_instructions'] = converted_record['special_pkg_instructions']
      converted_record.delete('special_pkg_instructions')

      recorder.logger.debug "Oracle record is #{odb_record}"
      recorder.logger.debug "The converted oracle record is #{converted_record}"

      error_count = self.db_check_order_master_hj( converted_record, hjdb, order, recorder )
      recorder.log_result( error_count == 0, "matching t_al_host_order_master records between HJ and Oracle", recorder.warning )
      total_error_count += error_count
    end
    total_error_count
  end

  def self.db_check_order_master_hj( oracle_record, hjdb, order, recorder )
    hj_sql_query = "SELECT * FROM t_al_host_order_master WHERE order_number = #{order}"
    self.db_check_order_hj( oracle_record, hjdb, 'master', hj_sql_query, recorder )
  end

  def self.db_check_order_detail( odb, hjdb, order, recorder = QALogger.new )
    total_error_count = 0

    oracle_sql_query = "SELECT * FROM xxmc.t_al_host_order_detail WHERE order_number = #{order}"
    recorder.logger.debug "Oracle SQL query is:\n#{oracle_sql_query}"

    cursor = odb.parse( oracle_sql_query )
    cursor.exec()
    while odb_record = cursor.fetch_hash()
      converted_record = self.key_lowercase( odb_record )
      line_number = converted_record['line_number']

      recorder.logger.debug "Oracle record is #{odb_record}"
      recorder.logger.debug "The converted oracle record is #{converted_record}"

      error_count = self.db_check_order_detail_hj( converted_record, hjdb, order, line_number, recorder )
      recorder.log_result( error_count == 0, "matching t_al_host_order_detail records between HJ and Oracle for line_number #{line_number}", recorder.warning )
      total_error_count += error_count
    end
    total_error_count
  end

  def self.db_check_order_detail_hj( oracle_record, hjdb, order, line_number, recorder )
    hj_sql_query = "SELECT * FROM t_al_host_order_detail WHERE order_number = #{order} AND line_number = #{line_number}"
    self.db_check_order_hj( oracle_record, hjdb, 'detail', hj_sql_query, recorder )
  end

  def self.db_check_order_hj( oracle_record, hjdb, label, hj_sql_query, recorder )
    error_count = 0

    recorder.logger.debug "HJ SQL query is:\n#{hj_sql_query}"
    result = hjdb.execute(hj_sql_query);
    result.each do |hj_record|
      recorder.logger.debug "HJ record is #{hj_record}"
      if label == 'detail'
        # SQL server seems to use floating point, not good for comparison
        # unit_price isn't an important field for HJ/Agile, so just drop it
        oracle_record.delete('unit_price')
        hj_record.delete('unit_price')
      end
      success = hj_record == oracle_record
      unless success
        recorder.logger.debug "order #{label} record does not match HJ: #{hj_record.to_a - oracle_record.to_a} vs Oracle: #{oracle_record.to_a - hj_record.to_a}"
        error_count += 1
      end
    end
    error_count
  end

  def self.key_lowercase( my_hash )
    converted_hash = {}
      my_hash.each_pair do |k,v|
        converted_hash.merge!({k.downcase => v})
      end
      converted_hash
  end
end
