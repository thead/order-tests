require 'spec_helper'

describe QATestEnv do

  # This is a chained set of tests that depend upon the state of an
  # order from previous testing steps. This is a requirement for an
  # order end to end test against a real test environment
  context 'end to end test steps' do
    it 'creates an order' do
      output = double('output').as_null_object
      qalogger = QALogger.new( LOGFILE, false, LABEL, output )
      $order = QATestEnv.new( qalogger )
      $order.recorder.warning = true
      $order.config_list = [ CONFIGFILE_BASIC ]
      expect( CreateEcommOrders.api_add( $order ) ).to eq 0
    end

    it 'validates a new order in ecomm' do
      expect( ValidateEcommOrders.db_check_new_all( $order ) ).to eq 0
    end

    it 'validates a new order in oracle' do
      expect( ValidateOracleOrders.db_check_new_all( $order ) ).to eq 0
    end

    it 'clears the one hour delay before booking' do
      expect( QAEcommUpdates.last_viewed_in_admin_now_all( $order ) ).to eq 0
    end

    it 'books an order in rudi' do
      expect( RudiOperations.command_line_all( $order ) ).to eq 0
    end

    it 'books an order in rudi again (idempotent test)' do
      expect( RudiOperations.command_line_all( $order ) ).to eq 0
    end

    it 'validates a booked order in ecomm' do
      expect( ValidateEcommOrders.db_check_booked_all( $order ) ).to eq 0
    end

    it 'validates a booked order in oracle' do
      expect( ValidateOracleOrders.db_check_booked_all( $order ) ).to eq 0
    end

    it 'compares a booked orders ecomm and oracle data' do
      expect( CompareDBOrders.db_check_booked_all( $order ) ).to eq 0
    end

    it 'invokes oracle processes to insert order in HJ table' do
      expect( OracleProgram.invoke_sales_order_fake_all( $order ) ).to eq 0
    end

    it 'waits for oracle processes to insert order in HJ table' do
      expect( ValidateOracleOrders.db_t_al_host_poll( $order ) ).to eq 0
    end

    it 'fakes HJ order wave/pick/sort/ship operations' do
      expect( CreateOracleShipments.db_add_all( $order ) ).to eq 0
    end

    it 'waits for shipped order data in oracle' do
      expect( ValidateOracleShipments.db_t_al_host_poll( $order ) ).to eq 0
    end

    it 'validates a shipped order in oracle' do
      expect( ValidateOracleShipments.db_check_agile_all( $order ) ).to eq 0
    end

    it 'ships an order in uniblab to ecomm' do
      expect( UniblabOperations.uniblab_all( $order ) ).to eq 0
    end

    it 'ships an order in uniblab to ecomm again (idempotent test)' do
      expect( UniblabOperations.uniblab_duplicate_all( $order ) ).to eq 0
    end

    it 'validates a shipped order in oracle after uniblab' do
      expect( ValidateOracleShipments.db_check_uniblab_all( $order ) ).to eq 0
    end

    it 'waits for capture services to complete on order' do
      expect( UniblabOperations.is_capture_complete_poll( $order ) ).to eq 0
    end

    it 'validates a capture complete order in ecomm' do
      expect( ValidateEcommOrders.db_check_captured_all( $order ) ).to eq 0
    end

    it 'compares a capture complete orders ecomm and oracle data' do
      expect( CompareDBOrders.db_check_captured_all( $order ) ).to eq 0
    end

    it 'invoices an order in rudi' do
      expect( RudiOperations.command_line_invoice_all( $order ) ).to eq 0
    end

    it 'invoices an order in rudi again (idempotent test)' do
      expect( RudiOperations.command_line_invoice_all( $order ) ).to eq 0
    end

    it 'validates an invoiced order in ecomm' do
      expect( ValidateEcommOrders.db_check_invoiced_all( $order ) ).to eq 0
    end

    it 'validates an invoiced order in oracle' do
      expect( ValidateOracleOrders.db_check_invoiced_all( $order ) ).to eq 0
    end

    it 'compares an invoiced orders ecomm and oracle data' do
      expect( CompareDBOrders.db_check_invoiced_all( $order ) ).to eq 0
    end
  end
end
