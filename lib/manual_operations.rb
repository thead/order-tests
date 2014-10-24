#!/usr/bin/env ruby

#
# Manual QA test operations that are useful in multiple situations
#

module ManualOperations
  # Manually wait for new orders to push
  def ManualOperations.manual_new_order_wait( test )
    puts 'MANUAL STEP: waiting an hour for new order(s)'
    if ( test.logger.debug? )
      test.logger.debug 'Manual wait skipped'
    else
      6.times {
        10.times {
          sleep 60
          putc '#'
        }
        putc '|'
      }
      puts
    end
    test.logger.info 'Manual one hour waiting is over'
    return 0
  end

  def ManualOperations.skip( test )
    return 0
  end

  def ManualOperations.wait_interactive( test )
    print 'MANUAL STEP: waiting until interactive input: '
    $stdin.gets  # Don't care what
    return 0
  end

  # Manually process order(s), don't worry about failure, ctrl-c works
  def ManualOperations.manual_process( test, label, skip = nil )
    puts "MANUAL STEP: Each order must be manually processed for #{label}"
    test.data.each do |order|
      if skip
        test.logger.debug "Manual #{label} processing for order #{order} skipped"
      else
        print "MANUAL STEP: Press enter (or ^c to abort) when manual #{label} processing is complete for order #{order}: "
        $stdin.gets # Don't care what
      end
    end
    test.logger.info "Orders #{test.data} have been manually processed for #{label}"
    return 0
  end

  # Manually check an order
  def ManualOperations.manual_check( test, label = 'your', manual = nil )
    error_count = 0
    puts "MANUAL STEP: Each order must validate #{label} record data manually"
    test.data.each do |order|
      # If manual responses are not provided via argument, run an interactive query
      if manual
        answer = manual
      else
        print "MANUAL STEP: Is order #{order} correct (y/n)? "
        answer = $stdin.gets.chomp
      end

      success = ( answer == "y" )
      test.recorder.log_result( success, "manual validation against #{label} record data for #{order}" )
      error_count += 1 unless success
    end

    return error_count
  end
end
