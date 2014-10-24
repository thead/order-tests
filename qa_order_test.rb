#!/usr/bin/env ruby

#
# this script will drive end to end order testing
#

# TODO:
#
# - Should all step output be logged?
#
# - Central networked location to store log files by default?
#
# - web formatted log file? log4r supports many file formats ...
#
# - Get hygene of repository reviewed, add what I'm missing
#   + Travis
#   + rake
#
# - Will trace/log/data collection on failure be helpful?
#
# - Logging error messages/stderr needed!!
#   + partially done, some cmd output but certainly not stderr and probably db connection failures
#
# - Document and/or test the testing env
#   + health/site test for testing target site
#
# - Record/validate what software version(s) is/are actually being tested
#
# - Support HJ DB invoke of sprocs
#
# - Support additional new order features:
#   + Gift certificate
#   + Store credit
#   + paypal
#   + CC + SC
#   + paid shipping
#   + taxes
#   + discounts
#   + customer account updates (email/address)
#

$LOAD_PATH << File.expand_path('../lib', __FILE__)
require 'qa_command_line'

# Packages referenced in defined_steps data structure
require 'create_ecomm_orders'
require 'create_oracle_shipments'
require 'ecomm_updates'
require 'find_orders'
require 'validate_ecomm_orders'
require 'validate_oracle_orders'
require 'validate_hj_orders'
require 'validate_oracle_shipments'
require 'compare_db_orders'
require 'compare_hj'
require 'manual_operations'
require 'rudi_operations'
require 'uniblab_operations'
require 'oracle_programs'

# Compute a default log file (~/qa-logging is assumed to exist at present)
arg_logfile = File.expand_path( File.join('~', 'qa-logging', File.basename("#{__FILE__}",'.rb') + '-' + Time.now.to_i.to_s + '-' + Process.pid.to_s + '-' + ENV['USER'] + '.log') )

# Define available test operations (all referenced methods must require a QATestEnv object and no other required parameters)
defined_steps = {
  'BookRudi'                => ['Book rudi order',               RudiOperations.method(:command_line_all)],
  'BookRudiQuery'           => ['Book rudi all',                 RudiOperations.method(:command_line_query_all)],
  'CancelRudi'              => ['Cancel rudi order',             RudiOperations.method(:command_line_cancel_all)],
  'CancelRudiQuery'         => ['Cancel rudi all',               RudiOperations.method(:command_line_cancel_query_all)],
  'ClearHourDelay'          => ['Clear booking delay',           QAEcommUpdates.method(:last_viewed_in_admin_now_all)],
  'CompareManual'           => ['Compare Ecomm/Oracle',          ManualOperations.method(:manual_check)],
  'CompareBooked'           => ['Compare DBs after booking',     CompareDBOrders.method(:db_check_booked_all)],
  'CompareHJOrder'          => ['Compare HJ/Oracle DBs for order', CompareHJ.method(:db_check_order_all)],
  'CompareCaptured'         => ['Compare DBs after capture',     CompareDBOrders.method(:db_check_captured_all)],
  'CompareGC'               => ['Compare DBs for gift cert.',    CompareDBOrders.method(:db_check_giftcertificate_all)],
  'CompareInvoiced'         => ['Compare DBs after invoicing',   CompareDBOrders.method(:db_check_invoiced_all)],
  'CompareCanceled'         => ['Compare DBs after cancel',      CompareDBOrders.method(:db_check_canceled_all)],
  'CreateAuto'              => ['Ecomm order creation',          CreateEcommOrders.method(:api_add)],
  'CreateManual'            => ['Ecomm order creation',          CreateEcommOrders.method(:manual_add)],
  'Exit'                    => ['Exit testing',                  QACommandLine.method(:set_clean_exit)],
  'FakeHJ'                  => ['Fake HJ from wave to ship',     CreateOracleShipments.method(:db_add_all)],
  'FakeHJCancel'            => ['Fake HJ all items full scratch',CreateOracleShipments.method(:db_add_cancel_all)],
  'FakeHJCancelOne'         => ['Fake HJ first item full scratch', CreateOracleShipments.method(:db_add_cancel_first_all)],
  'FakeHJFraud'             => ['Fake HJ fraud cancel order',    CreateOracleShipments.method(:db_add_fraud_all)],
  'FakeHJScratch'           => ['Fake HJ all items 1 scratch',   CreateOracleShipments.method(:db_add_scratch_all)],
  'FakeHJScratchOne'        => ['Fake HJ first item 1 scratch',  CreateOracleShipments.method(:db_add_scratch_first_all)],
  'FindNewOrder'            => ['Find a new order',              FindOrders.method(:new)],
  'FindNewGC'               => ['Find a new gift cert. order',   FindOrders.method(:new_gc)],
  'FindUnshippedOrder'      => ['Find day old unshipped order',  FindOrders.method(:unshipped)],
  'FindAgileShippedOrder'   => ['Find a shipped order',          FindOrders.method(:shipped)],
  'FindFraudCanceledOrder'  => ['Find a fraud order',            FindOrders.method(:fraud_canceled)],
  'InvoiceRudi'             => ['Invoice rudi order',            RudiOperations.method(:command_line_invoice_all)],
  'InvoiceRudiQuery'        => ['Invoice rudi all',              RudiOperations.method(:command_line_invoice_query_all)],
  'InvokeOracleSO'          => ['Invoke Oracle SO programs',     OracleProgram.method(:invoke_sales_order_all)],
  'InvokeOracleSOFake'      => ['Invoke Oracle Fake SO programs',OracleProgram.method(:invoke_sales_order_fake_all)],
  'ReshipUniblab'           => ['Reship via uniblab',            UniblabOperations.method(:uniblab_duplicate_all)],
  'ShipUniblab'             => ['Ship via uniblab',              UniblabOperations.method(:uniblab_all)],
  'ShipUniblabQuery'        => ['Ship via uniblab all',          UniblabOperations.method(:uniblab_query_all)],
  'Skip'                    => ['Skip an operation',             ManualOperations.method(:skip)],
  'VerifyEcommManual'       => ['Verify Ecomm',                  ValidateEcommOrders.method(:manual_check)],
  'VerifyEcommNew'          => ['Verify new Ecomm order',        ValidateEcommOrders.method(:db_check_new_all)],
  'VerifyEcommBooked'       => ['Verify Ecomm after booking',    ValidateEcommOrders.method(:db_check_booked_all)],
  'VerifyEcommCaptured'     => ['Verify Ecomm after capture',    ValidateEcommOrders.method(:db_check_captured_all)],
  'VerifyEcommGC'           => ['Verify Ecomm for gift cert.',   ValidateEcommOrders.method(:db_check_giftcertificate_all)],
  'VerifyEcommInvoiced'     => ['Verify Ecomm after invoice',    ValidateEcommOrders.method(:db_check_invoiced_all)],
  'VerifyEcommCanceled'     => ['Verify Ecomm after cancel',     ValidateEcommOrders.method(:db_check_canceled_all)],
  'VerifyOracleManual'      => ['Verify Oracle',                 ValidateOracleOrders.method(:manual_check)],
  'VerifyOracleNew'         => ['Verify Oracle new order',       ValidateOracleOrders.method(:db_check_new_all)],
  'VerifyOracleBooked'      => ['Verify Oracle after booking',   ValidateOracleOrders.method(:db_check_booked_all)],
  'VerifyOracleAgileShip'   => ['Verify Oracle Agile Ship',      ValidateOracleShipments.method(:db_check_agile_all)],
  'VerifyOracleUniblabShip' => ['Verify Oracle Uniblab Ship',    ValidateOracleShipments.method(:db_check_uniblab_all)],
  'VerifyOracleGC'          => ['Verify Oracle for gift cert.',  ValidateOracleOrders.method(:db_check_giftcertificate_all)],
  'VerifyOracleInvoiced'    => ['Verify Oracle after invoice',   ValidateOracleOrders.method(:db_check_invoiced_all)],
  'VerifyOracleCanceled'    => ['Verify Oracle after cancel',    ValidateOracleOrders.method(:db_check_canceled_all)],
  'WaitBookedPoll'          => ['Wait for booking',              ValidateEcommOrders.method(:is_booked_poll)],
  'WaitBookedProdPoll'      => ['Wait hours for booking',        ValidateEcommOrders.method(:is_booked_longpoll)],
  'WaitCanceledPoll'        => ['Wait for order cancel',         ValidateEcommOrders.method(:is_canceled_poll)],
  'WaitHJBookedPoll'        => ['Wait for HJ booking',           ValidateOracleOrders.method(:db_t_al_host_poll)],
  'WaitHJDownloadedPoll'    => ['Wait for HJ order download',    ValidateHJOrders.method(:is_downloaded_poll)],
  'WaitHJShippedPoll'       => ['Wait for HJ shipping',          ValidateOracleShipments.method(:db_t_al_host_poll)],
  'WaitHJShippedProdPoll'   => ['Wait days for HJ shipping',     ValidateOracleShipments.method(:db_t_al_host_longpoll)],
  'WaitShippedPoll'         => ['Wait for shipping',             ValidateOracleShipments.method(:is_shipped_poll)],
  'WaitUniblabProcessedPoll'=> ['Wait for Uniblab to run',       ValidateOracleShipments.method(:shipment_master_processed_poll)],
  'WaitCapturedPoll'        => ['Wait for capture complete',     UniblabOperations.method(:is_capture_complete_poll)],
  'WaitInvoicedPoll'        => ['Wait for invoicing',            ValidateEcommOrders.method(:is_invoiced_poll)],
  'WaitHour'                => ['Wait an hour',                  ManualOperations.method(:manual_new_order_wait)],
  'WaitManual'              => ['Manual interactive wait',       ManualOperations.method(:wait_interactive)]
}

# Defined list of testing steps to choose from
tests = {
  'default' => [
    'CreateAuto', 'VerifyEcommNew', 'VerifyOracleNew', 'ClearHourDelay', 'BookRudi', 'BookRudi',
    'VerifyEcommBooked', 'VerifyOracleBooked', 'CompareBooked', 'InvokeOracleSOFake', 'WaitHJBookedPoll', 'FakeHJ',
    'WaitHJShippedPoll', 'VerifyOracleAgileShip', 'ShipUniblab', 'ReshipUniblab', 'VerifyOracleUniblabShip',
    'WaitCapturedPoll', 'VerifyEcommCaptured', 'CompareCaptured', 'InvoiceRudi', 'InvoiceRudi',
    'VerifyEcommInvoiced', 'VerifyOracleInvoiced', 'CompareInvoiced' ],
  'fraud' => [
    'CreateAuto', 'VerifyEcommNew', 'VerifyOracleNew', 'ClearHourDelay', 'BookRudi', 'BookRudi',
    'VerifyEcommBooked', 'VerifyOracleBooked', 'CompareBooked', 'InvokeOracleSOFake', 'WaitHJBookedPoll', 'FakeHJFraud',
    'WaitHJShippedPoll', 'VerifyOracleAgileShip', 'ShipUniblab', 'ReshipUniblab', 'VerifyOracleUniblabShip',
    'CancelRudi', 'CancelRudi', 'VerifyEcommCanceled', 'VerifyOracleCanceled', 'CompareCanceled' ],
  'gift' => [
    'CreateManual', 'InvoiceRudi', 'InvoiceRudi', 'VerifyEcommGC', 'VerifyOracleGC', 'CompareGC' ],
  'watch' => [
    'FindNewOrder', 'VerifyEcommNew', 'VerifyOracleNew', 'WaitBookedPoll', 'VerifyEcommBooked',
    'VerifyOracleBooked', 'CompareBooked', 'WaitHJBookedPoll', 'WaitHJShippedProdPoll', 'VerifyOracleAgileShip',
    'WaitShippedPoll', 'VerifyOracleUniblabShip', 'WaitCapturedPoll', 'VerifyEcommCaptured',
    'CompareCaptured', 'WaitInvoicedPoll', 'VerifyEcommInvoiced', 'VerifyOracleInvoiced', 'CompareInvoiced' ],
  'watch_new' => [
    'FindNewOrder', 'VerifyEcommNew', 'VerifyOracleNew', 'WaitBookedPoll', 'VerifyEcommBooked',
    'VerifyOracleBooked', 'CompareBooked', 'WaitHJBookedPoll' ],
  'watch_gift' => [
    'FindNewGC', 'WaitInvoicedPoll', 'VerifyEcommGC', 'VerifyOracleGC', 'CompareGC' ],
  'watch_shipped' => [
    'FindAgileShippedOrder', 'VerifyOracleAgileShip', 'WaitShippedPoll', 'VerifyOracleUniblabShip', 'WaitCapturedPoll',
    'VerifyEcommCaptured', 'CompareCaptured', 'WaitInvoicedPoll', 'VerifyEcommInvoiced', 'VerifyOracleInvoiced', 'CompareInvoiced' ],
  'watch_fraud' => [
    'FindFraudCanceledOrder', 'VerifyOracleAgileShip', 'WaitUniblabProcessedPoll', 'VerifyOracleUniblabShip',
    'WaitCanceledPoll', 'VerifyEcommCanceled', 'VerifyOracleCanceled', 'CompareCanceled' ],
}

# Text used by help/usage option
usage_text = <<EOF
    This is a QA tool for testing order(s) from creation to complete. By default,
    a single random item order is generated, but custom orders can be requested
    with a json formatted order file or files.
EOF

# Init command line options and defaults
QACommandLine.initialize( 'order testing tool', usage_text )
QACommandLine.init_extra_args( 'config_files' )
QACommandLine.init_logfile( arg_logfile )
QACommandLine.init_steps( defined_steps, tests, 'default' )

# With processing steps initialized, we simply invoke process
exit QACommandLine.process
