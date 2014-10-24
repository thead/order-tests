#!/usr/bin/env ruby

#
# Class to support qa operations related to testing
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'ecomm_operations'
require 'oracle_operations'
require 'hj_operations'

# Create a testing data structure to pass around to different methods
class QATestEnv
  attr_accessor :data, :recorder, :location, :config_list, :repeat, :exit
  attr_reader :logger

  def initialize( recorder, location = QATestLocation.new, config_list = nil, repeat = 1 )
    @recorder = recorder
    @location = location
    @config_list = config_list
    @repeat = repeat
    @data = []
    @exit = false

    @edb_ro = @edb_rw = @odb_ro = @odb_rw = @hjdb_ro = @hjdb_rw = nil

    # Simply providing a shortcut
    @logger = recorder.logger
  end

  def edb_ro
    @edb_ro = QAEcomm.db_connect( @location, false ) unless @edb_ro
    @edb_ro
  end

  def edb_rw
    @edb_rw = QAEcomm.db_connect( @location, true ) unless @edb_rw
    @edb_rw
  end

  def odb_ro
    @odb_ro = QAOracle.db_connect( @location, false ) unless @odb_ro
    @odb_ro
  end

  def odb_rw
    @odb_rw = QAOracle.db_connect( @location, true ) unless @odb_rw
    @odb_rw
  end

  def hjdb_ro
    @hjdb_ro = QAHighjump.db_connect( @location, false ) unless @hjdb_ro
    @hjdb_ro
  end

  def hjdb_rw
    @hjdb_rw = QAHighjump.db_connect( @location, true ) unless @hjdb_rw
    @hjdb_rw
  end

  def db_close
    @edb_ro = QAEcomm.db_close( @edb_ro ) if @edb_ro
    @edb_rw = QAEcomm.db_close( @edb_rw ) if @edb_rw
    @odb_ro = QAOracle.db_close( @odb_ro ) if @odb_ro
    @odb_rw = QAOracle.db_close( @odb_rw ) if @odb_rw
    @hjdb_ro = QAHighjump.db_close( @hjdb_ro ) if @hjdb_ro
    @hjdb_rw = QAHighjump.db_close( @hjdb_rw ) if @hjdb_rw
  end
end
