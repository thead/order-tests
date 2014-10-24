#!/usr/bin/env ruby

#
# Invoke oracle concurrent programs
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'manual_operations'

module OracleProgram
  # Manually request invocation of an oracle program
  def self.manual_process( test, skip = nil )
    ManualOperations.manual_check( test, 'Oracle concurent programs', skip )
  end

  def self.invoke_all( test, program )
    test.data.reduce(0) do |total_error_count, order|
      error_count = self.invoke( test.odb_rw, order, program, test.recorder )
      test.recorder.log_result( error_count == 0, "invocation of oracle concurrent program #{program} for order #{order}" )
      total_error_count + error_count
    end
  end

  # Single orders argument wrappers to support qa_order_test stored method invocations
  def self.invoke_sales_order_all( test )
    self.invoke_all( test, 'XXMC Create Sales Order/Outbound To HJ' )
  end

  def self.invoke_sales_order_fake_all( test )
    self.invoke_all( test, 'XXMC Create Sales Order/Outbound To HJ FAKE' )
  end

  # Add order master/detail records for one order via oracle concurrent processes
  def self.invoke( odb, order, program, recorder = QALogger.new )
    case program
    when 'XXMC Create Sales Order/Outbound To HJ', 'XXMC Create Sales Order/Outbound To HJ FAKE'
      # If we plan to fake HJ operations for an order, we may prefer to hide that order from
      # HJ completely so it doesn't get used by another tester and we end up with two sets of
      # t_al_host_shipment_master records.
      if program == 'XXMC Create Sales Order/Outbound To HJ FAKE'
        sql_fix = <<EOF
DELETE xxmc.t_host_download_notify_intf
 WHERE status = 'NEW' AND
       host_group_id IN (SELECT host_group_id FROM xxmc.t_al_host_order_master WHERE order_number = #{order});
EOF
      else
        sql_fix = ''
      end
      sql_cmd = <<EOF
DECLARE

l_err_buf varchar2(4000) ;
l_ret_code number ;
l_batch_id number ;
my_id number ;

BEGIN

    SELECT interface_header_id
      INTO my_id
      FROM xxmc.xxmc_salesorder_headers_v2
     WHERE status = 'NEW' AND
           action = 'N' AND
           batch_id IS NULL AND
           rownum < 2 AND
           order_number = #{order};

    XXMC_CUSTOMER_PKG_API_V2.UPDATEINTERFACERECORDS (P_INTERFACE_HEADER_ID => my_id,
                                                     P_ERRBUF => l_err_buf,
                                                     P_RETCODE => l_ret_code
                                                      );

    SELECT xxmc_batch_sequence_s.nextval
      INTO l_batch_id FROM dual;

    UPDATE xxmc.xxmc_salesorder_headers_v2
       SET batch_id = l_batch_id
     WHERE status = 'NEW' AND
           action = 'N' AND
           batch_id IS NULL AND
           order_number = #{order};

    XXMC_ORDER_PROCESS_V2.POLL_ORDERS (P_RET_CODE => l_ret_code,
                                       P_ERROR_BUF => l_err_buf,
                                       P_BATCH_ID  => l_batch_id,
                                       P_SALES_ORDER_NUMBER => #{order} ,
                                       P_ORDER_TYPE => 'Standard Sales Order'
                                      ) ;

    XXMC_OUTBOUND_SO_INTERFACE.XXMC_OUTBOUND_SO_TO_HJ (X_ERRBUF => l_err_buf,
                                                       X_RETCODE => l_ret_code,
                                                       P_SALES_ORDER_NUMBER => #{order}
                                                      ) ;

#{sql_fix}
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
            COMMIT;
END;
EOF
    else
      recorder.logger.error "invoke requested for unknown program #{program}"
    end

    recorder.logger.debug "Oracle SQL to invoke #{program} for order #{order}:\n#{sql_cmd}"
    result = odb.exec( sql_cmd )
    recorder.logger.debug "Oracle SQL result from invoking #{program} for #{order} is #{result}"
    result == 1 ? 0 : 1
  end
end
