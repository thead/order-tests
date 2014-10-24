require 'spec_helper'

describe QAEcomm do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }
    let(:my_order) {
      qaorder.config_list = [ CONFIGFILE_BASIC ]
      CreateEcommOrders.api_add( qaorder )
      qaorder.data.first
    }

    context 'methods' do
        it "validates default querying an order" do
          db_orders = QAEcomm.db_connect().from(:orders)
          db_row = db_orders.where('orders.id=?', my_order).first
          db_order_id = db_row[:id]
          expect( db_order_id ).to eq my_order.to_i
        end

        it "validates querying an order" do
          db_orders = QAEcomm.db_connect(qaorder.location).from(:orders)
          db_row = db_orders.where('orders.id=?', my_order).first
          db_order_id = db_row[:id]
          expect( db_order_id ).to eq my_order.to_i
        end

        it "validates querying an order as an update user" do
          db_orders = QAEcomm.db_connect(qaorder.location, true ).from(:orders)
          db_row = db_orders.where('orders.id=?', my_order).first
          db_order_id = db_row[:id]
          expect( db_order_id ).to eq my_order.to_i
        end
    end
end
