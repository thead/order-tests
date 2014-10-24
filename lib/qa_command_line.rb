#!/usr/bin/env ruby

#
# Command line support for QA scripts
#

require 'getoptlong'

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_test_location'
require 'qa_test_env'

module QACommandLine
  # Initialize defaults
  DEFAULT_LOCATION = 'stage'
  CONFIG_DIR = File.expand_path('../../config', __FILE__)
  DEFAULT_ORDERFILE = "#{CONFIG_DIR}/order_api_post_basic.json"
  DEFAULT_REPEAT = 1

  # Required before calling process
  def self.initialize( command_name, command_desc, extra_args = nil )
    @command_name = command_name
    @command_desc = command_desc
    @extra_args = @extra_args_required = @extra_args_text = nil
    @logfile = nil
    @steps = @default_step_list = @step_list = nil
    @onsuccess = @onfailure = nil
    @step_abort = false
    @repeat = nil
    @quiet = false
  end

  # Optional to set up what to do with unprocessed arguments
  def self.init_extra_args( extra_args )
    @extra_args = extra_args
    case @extra_args
    when 'config_files'
      @extra_args_required = false
      @extra_args_text = '[ORDER FILES]'
      @repeat = DEFAULT_REPEAT
    when 'orders'
      @extra_args_required = true
      @extra_args_text = 'ORDERS'
    when nil
      @extra_args_required = false
      @extra_args_text = ''
    else
      @extra_args_required = true
      @extra_args_text = 'DATA'
    end
  end

  # Optional to set up a logfile
  def self.init_logfile( logfile )
    @logfile = ( logfile == '' ? nil : logfile )
  end

  # Optional to set up a multiple step test/operation
  def self.init_steps( steps , tests, default_test, onsuccess = nil, onfailure = nil )
    @steps = steps
    @tests = tests
    @default_test = default_test
    @onsucess = onsuccess
    @onfailure = onfailure

    @default_step_list = @tests[@default_test]
    @step_list = @default_step_list.clone
  end

  # Optional to allow multiple orders to be processed
  # Separate from order creation config files as Find
  # steps can also use repeat
  def self.init_repeat( repeat_value = DEFAULT_REPEAT )
    @repeat = repeat_value
  end

  # Process command line based on initialization
  def self.process
    # Process arguments and create test object
    # Use print for failures as the logger has not yet been created
    complete = false
    failure_code = 1
    begin
      test = process_setup()
      complete = true
    rescue Interrupt
      print '\nFatal Error :: Caught a fatal interrupt signal\n'
      failure_code = 255
    rescue SystemExit => e
      exit failure_code
    rescue Exception => e
      print "\nFatal Error :: Caught a fatal exception (#{e})\n"
      failure_code = 254
    end
    unless complete
      usage()
      exit failure_code
    end

    # Log test setup before execution
    test.logger.info "Test steps: #{@step_list}" if @steps
    test.logger.info "Test location config file: #{test.location.env_file}"
    filtered_location = test.location.data.reject { |key, value| key.to_s.include?('_USER') || key.to_s.include?('_PW') }
    test.logger.info "Test location data: #{filtered_location}"
    test.logger.info "Order json file(s): #{test.config_list}" unless test.config_list.empty?

    # Execute test(s)
    complete = false
    begin
      if @steps
        @step_list.each do |step|
          test.recorder.logged_step( test, @steps[step].first ) { |o| @steps[step].last.call o }
          if test.exit
            test.logger.info "Clean exit requested"
            break
          elsif @step_abort && (not test.recorder.success)
            test.logger.error "Aborting test on failing step"
            break
          end
        end
      else
        # If no steps were defined, yield to single method/block
        error_count = yield test
        test.recorder.success = error_count == 0
      end
      complete = true
    rescue Interrupt
      puts
      test.logger.fatal 'Caught a fatal interrupt signal'
      failure_code = 255
    rescue Exception => e
      puts
      test.logger.fatal "Caught a fatal exception (#{e})"
      failure_code = 254
    end

    # Compute success
    unless complete
      test.logger.fatal 'Test execution aborted or failed catastrophically'
      test.recorder.success = false
    end

    # Post execution step
    if @steps && ( (test.recorder.success && @onsuccess) || ((not test.recorder.success) && @onfailure) )
      if test.recorder.success
        post_process = @onsuccess
        post_label = "on success"
      else
        post_process = @onfailure
        post_label = "on failure"
      end

      post_complete = false
      begin
        test.logger.info( "Starting post-processing #{post_label} step" )
        test.recorder.logged_step( test, @steps[post_process].first ) { |o| @steps[post_process].last.call o }
        post_complete = true
      rescue Interrupt
        puts
        test.logger.fatal 'Caught a fatal interrupt signal during post processing'
        failure_code = 255
      rescue Exception => e
        puts
        test.logger.fatal "Caught a fatal exception (#{e}) during post processing"
        failure_code = 254
      end

      unless post_complete
        test.logger.fatal 'Test post-processing execution aborted or failed catastrophically'
        test.recorder.success = false
      end
    end

    # Output a summary and exit with a return code
    test.logger.info "Order processing is complete\n" if @steps
    test.recorder.summary
    exit test.recorder.success ? 0 : failure_code
  end

  ##############################

  # Create test object after processing arguments
  def self.process_setup
    opts = construct_opts()

    # Initialize defined arguments
    arg_debug = false
    arg_location = DEFAULT_LOCATION
    arg_repeat = @repeat
    arg_logfile = @logfile
    arg_overwrite = false
    arg_custom = arg_update = false
    arg_orderfiles = []
    arg_data = []
    arg_warning = false
    arg_step_replacements = []

    # Process args
    # All reporting must be via print as the logger has yet to be created
    opts.each do |opt, arg|
      case opt
      when '--abort'
        @step_abort = true if @steps
      when '--custom'
        # Incompatible with step update arguments
        if arg_update
          print "Fatal Error :: --custom incompatible with --# updates"
          usage()
          exit 2
        elsif @steps
          arg_step_list = arg.split
          diff_list = arg_step_list - @steps.keys
          unless diff_list.length == 0
            print "Fatal Error :: unrecognized test steps #{diff_list}"
            usage()
            exit 2
          end
          @step_list = arg_step_list
          arg_custom = true
        end
      when '--debug'
        arg_debug = true
      when '--help', '--usage'
        usage()
        exit 0
      when '--location'
        arg_location = arg
      when '--locations'
        locations = Dir["#{CONFIG_DIR}/*"].select { |f| f =~ /.*\.sh/}.map {|f| File.basename(f,'.sh')} - ['unset']
        print "Available locations are #{locations}\n"
        exit 0
      when '--logfile'
        if @logfile
          arg_logfile = ( arg == '' ? nil : File.expand_path(arg) )
        end
      when '--onfailure'
        if @steps
          if @steps.keys.include? arg
            @onfailure = arg
          else
            print "Fatal Error :: unrecognized onfailure step #{arg}"
          end
        end
      when '--onsuccess'
        if @steps
          if @steps.keys.include? arg
            @onsuccess = arg
          else
            print "Fatal Error :: unrecognized onsucces step #{arg}"
          end
        end
      when '--overwrite'
        arg_overwrite = true if @logfile
      when '--quiet'
        @quiet = true
      when '--repeat'
        arg_repeat = arg.to_i
      when '--test'
        if @steps
          unless @tests[arg]
            print "Fatal Error :: unrecognized test #{arg}"
            usage()
            exit 2
          end
          self.init_steps( @steps, @tests, arg )
        end
      when '--warning'
        arg_warning = true
      when /--\d+/
        # Incompatible with custom argument
        if arg_custom
          print "Fatal Error :: --# incompatible with --custom updates"
          usage()
          exit 2
        elsif @steps
          index = opt.scan(/\d+/).first.to_i - 1
          if not @steps.keys.include?(arg)
            print "Fatal Error :: unrecognized test step #{arg}"
            usage()
            exit 2
          else
            arg_step_replacements << [index,arg]
            arg_update = true
          end
        end
      else
        print "Fatal Error :: unrecognized argument #{arg}"
        usage()
        exit 2
      end
    end

    # Process step replacements after all other defined args
    arg_step_replacements.each do |index,step|
      if index >= @step_list.length
        print "Fatal Error :: unrecognized test index --#{index+1}"
        usage()
        exit 2
      end
      @step_list[index] = step
    end

    # Check if undefined additional args are required and process
    if @extra_args_required and ARGV.length == 0
      print 'Fatal Error :: insufficient arguments'
      usage()
      exit 2
    elsif @extra_args == nil and ARGV.length > 0
      print 'Fatal Error :: excessive arguments'
      usage()
      exit 2
    elsif @extra_args == 'config_files'
      ARGV.each do |file|
        arg_orderfiles << File.expand_path( file )
      end
    else
      arg_data = ARGV.clone
    end

    # Validate argument data
    if @logfile && arg_logfile
      logdir = File.dirname( arg_logfile )
      if ( not File.exists?( logdir ) )
        print "Fatal Error :: Directory for log file #{$arg_logfile} does not exist\n"
        exit 2
      end
      if ( File.exists?( arg_logfile ) && arg_overwrite == false )
        print "Fatal Error :: Log file #{$arg_logfile} already exists and the overwrite option was not used\n"
        exit 2
      end
    end

    if @extra_args == 'config_files'
      arg_orderfiles << DEFAULT_ORDERFILE if arg_orderfiles.empty?
      arg_orderfiles.each do |file|
        unless File.exists?( file )
          print "Fatal Error :: Order file #{file} does not exist\n"
          exit 2
        end
      end
    end

    # Set up location data
    location_file = File.expand_path("#{CONFIG_DIR}/#{arg_location}.sh")
    if File.file?(location_file)
      location = QATestLocation.new( arg_location, location_file )
    else
      print "Fatal Error :: Location env file #{location_file} does not exist\n"
      exit 3
    end

    # Create logger
    log = QALogger.new( arg_logfile, arg_debug, @command_name )
    log.quiet if @quiet

    # Create a test object and populate it with the unprocessed command line arguments
    test = QATestEnv.new( log, location, arg_orderfiles, arg_repeat )
    test.data = arg_data
    test.recorder.warning = arg_warning
    test
  end

  def self.construct_opts
    opts_array = [
      [ '--debug', '-d',     GetoptLong::NO_ARGUMENT ],
      [ '--help', '-h',     GetoptLong::NO_ARGUMENT ],
      [ '--location', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--locations', '-l', GetoptLong::NO_ARGUMENT ],
      [ '--quiet', '-q', GetoptLong::NO_ARGUMENT ],
      [ '--usage', '-u',    GetoptLong::NO_ARGUMENT ],
      [ '--warning', '-w',    GetoptLong::NO_ARGUMENT ]
    ]
    opts_array.push(
      [ '--logfile', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--overwrite', '-o', GetoptLong::NO_ARGUMENT ]
    ) if @logfile
    opts_array.push(
      [ '--repeat', GetoptLong::REQUIRED_ARGUMENT ]
    ) if @extra_args == 'config_files' || @repeat
    opts_array.push(
      [ '--abort', '-a',     GetoptLong::NO_ARGUMENT ],
      [ '--custom', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--onfailure', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--onsuccess', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--test', GetoptLong::REQUIRED_ARGUMENT ]
    ) if @steps
    opts_array.concat( @default_step_list.each_index.map {|i| ["--#{i+1}", GetoptLong::REQUIRED_ARGUMENT]}) if @steps
    GetoptLong.new( *opts_array )
  end

  def self.usage
    puts <<-EOF

USAGE: #{$0} [OPTIONS] #{@extra_args_text}

Description:

#{@command_desc}

#{general_usage} #{logfile_usage} #{config_file_usage} #{step_usage}
    EOF
  end

  def self.general_usage
    <<-EOF
General options:

    -d, --debug:
        enable debug logging

    -h, --help, -u, --usage:
        show help and exit

    --location location_string
        location/site to run test against (default #{DEFAULT_LOCATION})

    -l, --locations:
        return supported locations and exit

    -q, --quiet:
        disables most screen output

    -w, --warning:
        enable warnings as non-failing checks
    EOF
  end

  def self.logfile_usage
    if @logfile
      <<-EOF

Logfile options:

    --logfile filename
        logfile to send logging messages to (default #{@logfile})

    -o, --overwrite
        if log file already exists, overwrite its contents
      EOF
    else
      ''
    end
  end

  def self.config_file_usage
    if @extra_args == 'config_files' || @repeat
      <<-EOF

Order creation/discovery options:

    --repeat count
        if an order creation/discovery step is selected, this option
        will repeat the step count times (default #{DEFAULT_REPEAT})
      EOF
    else
      ''
    end
  end

  def self.step_usage
    if @steps
      <<-EOF

Step options:

    -a, --abort
        if enabled, failure at any given step will abort the test at the end of that step

    --custom 'step ...'
        incompatible with --\# options
        replace the default test steps with a custom, space separated list of available test steps

    --onfailure step
        Step to run if test fails (default none)

    --onsuccess step
        Step to run if test succeeds (default none)

    --test test-set
        set of testing steps to use (currently set to #{@default_test})
        available testing sets are: #{@tests.keys}

    --1..#{@default_step_list.length} step
        incompatible with --custom
        Replace one of the default test steps with the provided step label. Default steps are:
#{step_usage_default}

#{step_usage_defined}
      EOF
    else
      ''
    end
  end

  def self.step_usage_default
    return_string = "\n"
    usage_array = @default_step_list.each_index.map {|i| "--#{i+1} #{@default_step_list[i]}"}
    return_string.concat self.table_format( usage_array, 100, 8)
  end

  def self.step_usage_defined
    return_string = "    Available steps are:\n\n"
    return_string.concat self.table_format( @steps.keys, 100, 8 )
  end

  # Generate string of array data formatted into a table
  def self.table_format( string_array, width, left_buffer=0 )
    working_width = width - left_buffer
    max_len = string_array.reduce(0) {|m,v| v.length > m ? v.length : m }
    elements_per_line = working_width / (max_len + 1)
    array_step = (string_array.length / elements_per_line.to_f).ceil

    # Split string array into 2D array of string elements in each output line
    table_array = (0...array_step).map do |start|
      (start...string_array.length).step(array_step).map {|i| string_array[i]}
    end

    # Create an output string out of lines of left justified elements
    return_string = ''
    table_array.each do |line|
      return_string.concat ' ' * left_buffer
      line.each do |column|
        return_string.concat column.ljust(max_len + 1)
      end
      return_string.concat "\n"
    end
    return_string
  end

  def self.set_clean_exit( test )
    test.exit = true
    return 0
  end
end
