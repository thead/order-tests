#!/usr/bin/env ruby

#
# Query Oracle data
#

$LOAD_PATH << File.expand_path('..', __FILE__)

module QAOracleQuery
  # Return data field or nil
  def self.get_field(odb, in_data, label, recorder = QALogger.new)
    case label
    when 'shipment master processing status'
      odb_query_str = <<EOF
SELECT processing_status AS DATA
  FROM xxmc.t_al_host_shipment_master
 WHERE order_number = #{in_data}
EOF
    else
      recorder.logger.error "get_field received unknown label #{label}"
      return nil
    end
    recorder.logger.debug "Oracle #{label} SQL for #{in_data}:\n#{odb_query_str}"

    cursor = odb.parse( odb_query_str )
    cursor.exec()

    odb_row = cursor.fetch_hash()
    data = odb_row ? odb_row['DATA'] : nil
    recorder.logger.debug "Oracle #{label} data for #{in_data}: #{data}"

    return data
  end

  # Return array of hashes or nil
  def self.get_array( odb, in_data, label, recorder = QALogger.new )
      case label
      when 'latest shipped order'
        odb_query_str = <<EOF
SELECT order_number FROM (
       SELECT DISTINCT m.order_number, m.record_create_date
         FROM xxmc.t_al_host_shipment_master m, xxmc.t_al_host_shipment_detail d
        WHERE m.host_group_id = d.host_group_id AND
              d.quantity_shipped > 0 AND
              m.fraud_cancellation = 'N' AND
              m.split_status in ('NOSPLIT', 'LAST') AND
              m.processing_status = 'NEW'
     ORDER BY m.record_create_date DESC )
 WHERE ROWNUM <= #{in_data}
EOF
    when 'latest fraud canceled order'
      odb_query_str = <<EOF
SELECT order_number FROM (
       SELECT order_number
         FROM xxmc.t_al_host_shipment_master
        WHERE fraud_cancellation = 'Y' AND
              split_status in ('NOSPLIT', 'LAST') AND
              processing_status = 'NEW'
     ORDER BY record_create_date DESC )
 WHERE ROWNUM <= #{in_data}
EOF
      when 'waiting to ship day old order'
        odb_query_str = <<EOF
SELECT order_number FROM (
       SELECT order_number
         FROM xxmc.t_al_host_order_master
        WHERE order_number NOT IN (SELECT order_number FROM xxmc.t_al_host_shipment_master) AND
              record_create_date < SYSDATE - (INTERVAL '1' DAY)
     ORDER BY record_create_date DESC )
 WHERE ROWNUM <= #{in_data}
EOF
      else
        recorder.logger.error "get_array received unknown label #{label}"
        return nil
      end
      recorder.logger.debug "Oracle #{label} SQL:\n#{odb_query_str}"

      cursor = odb.parse( odb_query_str )
      cursor.exec()
      odb_rows = []
      while record = cursor.fetch_hash()
        odb_rows << record
      end

      recorder.logger.debug "Oracle #{label} data: #{odb_rows}"

      # If the Oracle data is not available, bail
      if (not odb_rows) or (odb_rows.length == 0)
        recorder.logger.error "No Oracle records found"
        return nil
      end
      return odb_rows
  end
end
