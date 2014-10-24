#!/usr/bin/env ruby

#
# Given the number of days to check, validate all unshipped orders that are marked
# as downloaded are in HJ and data matches Oracle
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'compare_hj'

QACommandLine.initialize( 'Check HJ status of unshipped orders marked downloaded', '    This is a QA script for checking the HJ status of unshipped orders marked downloaded within given number of days' )
QACommandLine.init_extra_args( 'data' )
exit QACommandLine.process { |o|
  history = o.data.first
  sql_query = <<EOF
  SELECT UNIQUE O.ORDER_NUMBER FROM XXMC.T_AL_HOST_ORDER_MASTER O, XXMC.T_HOST_DOWNLOAD_NOTIFY_INTF D
   WHERE D.HOST_GROUP_ID = O.HOST_GROUP_ID AND
         D.CREATEDON > SYSDATE - (INTERVAL '#{history}' DAY) AND
         D.STATUS = 'COMPLETED' AND
         O.ORDER_NUMBER NOT IN (SELECT ORDER_NUMBER FROM XXMC.T_AL_HOST_SHIPMENT_MASTER WHERE HOST_GROUP_ID NOT LIKE 'FAKE%')
EOF
  o.logger.debug "SQL query is:\n#{sql_query}"

  cursor = o.odb_ro.parse( sql_query )
  cursor.exec()

  o.data = []
  while record = cursor.fetch_hash()
    o.data << record['ORDER_NUMBER']
  end
  o.logger.info "The #{o.data.length} orders downloaded but not shipped in oracle within the past #{history} days are:\n#{o.data}"

  CompareHJ.db_check_order_all(o)
}
