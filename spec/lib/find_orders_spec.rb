require 'spec_helper'

describe FindOrders do
      let(:output)   { double('output').as_null_object }
      let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
      let(:qaorder)  { QATestEnv.new( qalogger ) }

  context 'end to end order find' do
    # Make sure test env is seeded with an order to find
    it 'finds a new order' do
      qaorder.recorder.warning = true
      qaorder.config_list = [ CONFIGFILE_BASIC ]
      expect( CreateEcommOrders.api_add( qaorder ) ).to eq 0
      expect( QAEcommUpdates.last_viewed_in_admin_now_all( qaorder ) ).to eq 0
      qaorder.data = []
      expect( FindOrders.new( qaorder ) ).to eq 0
    end

    # Can not create a gift certificate via tools
    # Can not easily generate a day old unshipped order

    it 'finds a shipped order' do
      qaorder.recorder.warning = true
      qaorder.config_list = [ CONFIGFILE_BASIC ]
      expect( CreateEcommOrders.api_add( qaorder ) ).to eq 0
      expect( QAEcommUpdates.last_viewed_in_admin_now_all( qaorder ) ).to eq 0
      expect( RudiOperations.command_line_all( qaorder ) ).to eq 0
      expect( OracleProgram.invoke_sales_order_fake_all( qaorder ) ).to eq 0
      expect( CreateOracleShipments.db_add_all( qaorder ) ).to eq 0
      qaorder.data = []
      expect( FindOrders.shipped( qaorder ) ).to eq 0
    end

    it 'finds a fraud canceled order' do
      qaorder.recorder.warning = true
      qaorder.config_list = [ CONFIGFILE_BASIC ]
      expect( CreateEcommOrders.api_add( qaorder ) ).to eq 0
      expect( QAEcommUpdates.last_viewed_in_admin_now_all( qaorder ) ).to eq 0
      expect( RudiOperations.command_line_all( qaorder ) ).to eq 0
      expect( OracleProgram.invoke_sales_order_fake_all( qaorder ) ).to eq 0
      expect( CreateOracleShipments.db_add_fraud_all( qaorder ) ).to eq 0
      qaorder.data = []
      expect( FindOrders.fraud_canceled( qaorder ) ).to eq 0
    end
  end
end
