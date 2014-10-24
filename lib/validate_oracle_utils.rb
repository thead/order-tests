#!/usr/bin/env ruby

#
# Common methods used by oracle validation tests
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'
require 'qa_operations'

module ValidateOracleUtils
  # Check that no records exist for the given query
  def self.record_does_not_exist(odb, sql_str, label, recorder = QALogger.new )
    recorder.logger.debug "SQL query is:\n#{sql_str}"

    success = odb.exec(sql_str).fetch ? false : true
    recorder.log_result( success, "verification that #{label} not found" )

    return success ? 0 : 1
  end

  # For the given query, check a hash of record key/value pairs with debugging/reporting support
  def self.record_check(odb, sql_str, checks, label, recorder = QALogger.new )
    self.record_validate(odb, sql_str, checks, [], label, recorder)
  end

  def self.record_warning(odb, sql_str, warnings, label, recorder = QALogger.new )
    self.record_validate(odb, sql_str, [], warnings, label, true, recorder)
  end

  def self.record_validate(odb, sql_str, checks, warnings, label, recorder = QALogger.new )
    recorder.logger.debug "SQL query is:\n#{sql_str}"

    cursor = odb.parse( sql_str )
    cursor.exec()

    found = false
    error_count = 0
    while record = cursor.fetch_hash()
      # The sql command includes a test_label field, add it to the test output string
      if record['TEST_LABEL']
        xlabel = " (#{record['TEST_LABEL']})"
      else
        xlabel = ''
      end
      found = true
      warnings.each { |key,value|
        error_count += 1 unless QAOperations.data_check( record[key.to_s.upcase], "ODB #{key} field in the #{label}#{xlabel}", value, "#{value == nil ? 'null':value}", true, recorder )
      }
      checks.each { |key,value|
        error_count += 1 unless QAOperations.data_check( record[key.to_s.upcase], "ODB #{key} field in the #{label}#{xlabel}", value, "#{value == nil ? 'null':value}", false, recorder )
      }
    end

    recorder.log_result( found, "verification that record(s) for the #{label} found" )
    error_count += 1 unless found

    return error_count
  end
end
