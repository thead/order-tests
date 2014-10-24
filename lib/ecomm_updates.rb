#!/usr/bin/env ruby

#
# Support for direct updates/changes to the Ecomm DB
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'ecomm_queries'

module QAEcommUpdates
  def self.last_viewed_in_admin_now_all( test )
    test.logger.info 'Updating the last_viewed_in_admin_at on the Ecomm DB for all orders'

    updated = true
    test.data.each do |order|
      updated &= test.recorder.indent_logging { last_viewed_in_admin_now( test.edb_rw, order, test.recorder ) }
    end

    # Report pass/fail for update operation
    test.recorder.log_result( updated, 'updating the last_viewed_in_admin_at on the Ecomm DB for all orders' )
    return updated ? 0:1
  end

  # Lower level method does not need orders/logger/location, can be invoked independent of those objects
  def self.last_viewed_in_admin_now( edb, order, recorder = QALogger.new )
      book_time = QAEcommQuery.get_field(edb, order, 'order book time', recorder)
      recorder.logger.debug "Before update: #{book_time} for #{order}"

      success = edb.from(:orders).select(:internal_state_id).where('id=?',order).count == 1 && edb.from(:orders).where('id=?', order).update('last_viewed_in_admin_at' => Time.now)

      book_time = QAEcommQuery.get_field(edb, order, 'order book time', recorder)
      recorder.logger.debug "After update: #{book_time} for #{order}"
      recorder.log_result( success, "updating last_viewed_in_admin_at on Ecomm DB for #{order}")
      return success
  end
end
