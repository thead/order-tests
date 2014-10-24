#!/usr/bin/env ruby

#
# Class to support qa logging operations
#

require 'colorize'
require 'log4r'
include Log4r

# Manage the logging, execution time measurements and success state of a multi-step test
class QALogger
  attr_reader :logger, :logfile_name, :start_time, :stop_time, :label
  attr_accessor :success, :indent

  def initialize( logfile_name = nil, enable_debug = false , label = nil, primary_output = 'stdout' )
    @indent = 0
    @indent_size = 4

    @logger = Logger.new( 'mylog' )
    @logfile_name = logfile_name

    # If the default 'stdout' is not given, primary_output is treated as a general IO object
    # Used by rspec to validate output
    # We store @stdout/@logfile so we can change their attributes as needed (like formatter during summary output)
    if ( primary_output == 'stdout' )
      @stdout = Outputter.stdout
    else
      @stdout = IOOutputter.new( 'rspec_outputter', primary_output )
    end
    if @logfile_name
      @logfile = FileOutputter.new( 'fileOutputter',filename: @logfile_name,trunc: true )
      @logger.outputters = @stdout, @logfile
    else
      @logfile = nil
      @logger.outputters = @stdout
    end

    @success = true
    @step_count = @pass_count = @fail_count = 0

    @start_time = Time.now
    @stop_time = nil

    default_logging()
    debug( enable_debug )
    self.warning = false

    @label = label

    if @label
      start_string = "Starting #{@label}"
      if @logfile
        start_string += ", log file #{@logfile_name}"
      else
        start_string += " (PID #{Process.pid.to_s})"
      end
      @logger.info start_string
    end
    @logger.debug 'Debugging is enabled'
  end

  def quiet()
    @logger.remove 'stdout'
  end

  def loud()
    # To insure we don't have duplicate 'stdout' entries, remove stdout (no op if missing) before adding it
    @logger.remove 'stdout'
    @logger.add 'stdout'
  end

  # update the logging indent level and recompute output formatters
  def update_logging_indent( level )
    @indent += level
    @indent = 0 if @indent < 0
    default_logging()
  end

  # Consider updating this routine to take a list argument for outputters to update rather than hard coding @stdout/@logfile
  def default_logging
    default_format = PatternFormatter.new( pattern: "[%-5l] %d ::#{' ' * @indent * @indent_size} %m" )
    @stdout.formatter = default_format
    @logfile.formatter = default_format if @logfile
  end

  # Same here
  def summary_logging
    summary_format = PatternFormatter.new( pattern: '[SUMMARY] %m' )
    @stdout.formatter = summary_format
    @logfile.formatter = summary_format if @logfile
  end

  # May make argument optional, simply returning current debug level if enable not given?
  def debug( enable )
    @debug = enable
    if (@debug)
      @logger.level = Log4r::DEBUG
    else
      @logger.level = Log4r::INFO
    end
  end

  def warning=( enable )
    @logger.debug "Warnings are #{enable ? 'enabled':'disabled'}"
    @warning = enable
  end

  def warning
    @warning
  end

  # First argument ( test data structure ) passed to test step block via yield
  def logged_step( test, label )
    start_time = Time.now
    @logger.info "#{label} started"

    update_logging_indent( +1 )
    error_count = yield test
    update_logging_indent( -1 )
    stop_time = Time.now

    @step_count += 1
    info_string = " in #{stop_time - start_time} seconds - orders processed: #{test.data}"
    if ( error_count == 0 )
       @logger.info "#{label} " + 'PASSED'.green + info_string
       @pass_count += 1
    else
       @logger.error "#{label} " + 'FAILED'.red + info_string
       @fail_count += 1
       @success = false
    end

    return ( error_count == 0 )
  end

  # The yielded block generates indented logging output
  def indent_logging
    update_logging_indent( +1 )
    error_count = yield
    update_logging_indent( -1 )
    return error_count
  end

  def log_result( passed, string, check_warning = false )
    if passed
      @logger.info 'PASSED '.green + string
    else
      if check_warning && @warning
        @logger.info 'WARNING - FAILED '.yellow + string
        return true
      else
        @logger.error 'FAILED '.red + string
      end
    end
    passed
  end

  def summary
    @stop_time = Time.now
    return unless @label

    time_string =  "Execution time was #{stop_time - start_time} seconds"

    if (@success)
      result_string = 'PASSED'.green
      result_string.concat " all #{@step_count} steps" if @step_count > 0
    else
      result_string = 'FAILED'.red
      result_string.concat " #{@fail_count} of #{@step_count} steps" if @step_count > 0
    end

    # Change log format for summary results
    summary_logging()

    summary_string = "RESULT: #{@label}"
    summary_string += " (PID #{Process.pid.to_s})" if not @logfile
    summary_string += " #{result_string} -- #{time_string}"
    summary_string += " -- Log file #{@logfile_name}" if @logfile

    loud()
    @logger.info summary_string
  end
end
