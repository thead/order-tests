#!/usr/bin/env ruby

#
# Support general purpose QA operations
#

module QAOperations
  # Default of 20 minutes polling before failing
  POLL_MAX_CYCLES = 20
  POLL_SLEEP_CYCLE = 60

  # Poll for all orders to succeed at given yield routine
  def self.poll( test, max_cycles = POLL_MAX_CYCLES, sleep_cycle = POLL_SLEEP_CYCLE )
    cycles = 0
    orders_clone = test.data.clone
    while (not orders_clone.empty?) and (cycles < max_cycles)
      orders_clone.each do |order|
        if yield order
          orders_clone.delete order
          test.recorder.log_result( true, "order #{order} wait" )
        end
      end
      unless orders_clone.empty?
        # drop db connections and sleep
        test.db_close
        sleep sleep_cycle
        cycles += 1
      end
    end

    # Report success from polling
    complete = orders_clone.empty?
    test.logger.error "No completion for #{orders_clone}" unless complete
    return complete ? 0:1
  end

  def self.data_check( data1, data1_label, data2, data2_label, warning = false, recorder = QALogger.new )
    recorder.logger.debug "#{data1_label}: #{data1} is being compared to #{data2_label}: #{data2}"
    success = (data1 == data2)
    recorder.log_result( success, "matching #{data1_label} to #{data2_label}", warning )
  end

  def self.data_check_basic( data1, data1_label, data2, recorder = QALogger.new )
    self.data_check( data1, data1_label, data2, "#{data2 == nil ? 'null':data2}", false, recorder )
  end
end
