require 'spec_helper'

describe CreateEcommOrders do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }

    context 'initialization' do
        it 'generates an empty order list' do
          expect( qaorder.data ).to be_empty
        end
    end

    context 'order creation' do
        it "manually adds an order" do
          my_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_order )
          expect( qaorder.data.first ).to eq my_order
        end

        it "manually adds multiple orders" do
          my_orders = '1 2'
          CreateEcommOrders.manual_add( qaorder, my_orders )
          expect( qaorder.data.first ).to eq my_orders.split.first
          expect( qaorder.data.last ).to eq my_orders.split.last
        end

        it "creates a basic order via order API" do
          qaorder.config_list = [ CONFIGFILE_BASIC ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 1
        end

        it "creates multiple basic orders with multiple config files via order API" do
          qaorder.config_list = [ CONFIGFILE_BASIC, CONFIGFILE_BASIC ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 2
        end

        it "creates multiple basic orders with one config file via order API" do
          qaorder.config_list = [ CONFIGFILE_TWO ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 2
        end

        it "creates multiple basic orders with repeat value via order API" do
          qaorder.config_list = [ CONFIGFILE_BASIC ]
          qaorder.repeat = 2
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 2
        end

        # This can fail on the vintage item as often there are
        # no available vintage items in a test environment
        it "creates a random order via order API" do
          qaorder.config_list = [ CONFIGFILE_RANDOM ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 1
        end

        it "creates an explicit sku order via order API" do
          qaorder.config_list = [ CONFIGFILE_SKU ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 1
        end

        it "creates an explicit upc order via order API" do
          qaorder.config_list = [ CONFIGFILE_UPC ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 1
        end

        # This can fail if the selected existing user
        # has been overused for automated order testing
        it "creates an explicit user order via order API" do
          qaorder.config_list = [ CONFIGFILE_USER ]
          CreateEcommOrders.api_add( qaorder )
          expect( qaorder.data.length ).to eq 1
        end

        it "fails on a missing json file via order API" do
          qaorder.config_list = [ 'does_not_exist' ]
          expect( qaorder.data.length ).to eq 0
        end

        it "fails on an empty/invalid json file via order API" do
          qaorder.config_list = [ '/dev/null' ]
          expect( qaorder.data.length).to eq 0
        end
    end
end
