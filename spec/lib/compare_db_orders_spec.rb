require 'spec_helper'

describe CompareDBOrders do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }

    after(:each) { qaorder.db_close() if defined? qaorder }

    context 'methods' do
        it "validates a single order manually" do
          my_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_order )
          expect( ManualOperations.manual_check( qaorder, 'Ecomm', 'y' ) ).to eq 0
        end

        it "invalidates an order manually" do
          my_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_order )
          expect( ManualOperations.manual_check( qaorder, 'Ecomm', 'n' ) ).to eq 1
        end

        it "validates for multiple orders manually" do
          my_orders = '1 2'
          CreateEcommOrders.manual_add( qaorder, my_orders )
          expect( ManualOperations.manual_check( qaorder, 'Ecomm', 'y' ) ).to eq 0
        end

        it "validates a booked order via a DB query" do
          qaorder.config_list = [ CONFIGFILE_BASIC ]
          qaorder.recorder.warning = true
          expect( CreateEcommOrders.api_add( qaorder ) ).to eq 0
          expect( RudiOperations.command_line_all(qaorder) ).to eq 0
          expect( CompareDBOrders.db_check_booked_all( qaorder ) ).to eq 0
        end

        it "invalidates an incorrect booked order via a DB query" do
          my_invalid_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_invalid_order )
          expect( CompareDBOrders.db_check_booked_all( qaorder ) ).to_not eq 0
        end

        it "validates multiple booked orders via a DB query" do
          qaorder.config_list = [ CONFIGFILE_TWO ]
          qaorder.recorder.warning = true
          expect( CreateEcommOrders.api_add( qaorder ) ).to eq 0
          expect( RudiOperations.command_line_all(qaorder) ).to eq 0
          expect( CompareDBOrders.db_check_booked_all( qaorder ) ).to eq 0
        end

        it "invalidates an incorrect captured order via a DB query" do
          my_invalid_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_invalid_order )
          expect( CompareDBOrders.db_check_captured_all( qaorder ) ).to_not eq 0
        end

        it "invalidates an incorrect invoiced order via a DB query" do
          my_invalid_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_invalid_order )
          expect( CompareDBOrders.db_check_invoiced_all( qaorder ) ).to_not eq 0
        end

        it "invalidates an incorrect canceled order via a DB query" do
          my_invalid_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_invalid_order )
          expect( CompareDBOrders.db_check_canceled_all( qaorder ) ).to_not eq 0
        end

        it "invalidates an incorrect gift certificate order via a DB query" do
          my_invalid_order = '1'
          CreateEcommOrders.manual_add( qaorder, my_invalid_order )
          expect( CompareDBOrders.db_check_giftcertificate_all( qaorder ) ).to_not eq 0
        end
    end
end
