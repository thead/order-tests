require 'spec_helper'

describe RudiOperations do
    let(:output)         { double('output').as_null_object }
    let(:qalogger)       { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)        { QATestEnv.new( qalogger ) }

    context 'methods' do
        it "books a single order via rudi using a command line tool" do
          qaorder.config_list = [ CONFIGFILE_BASIC ]
          CreateEcommOrders.api_add( qaorder )
          expect( RudiOperations.command_line_all( qaorder ) ).to eq 0
        end

        it "books all outstanding orders via rudi using a command line tool" do
          expect( RudiOperations.command_line_query_all( qaorder ) ).to eq 0
        end

        it "fails on an invalid order using a command line tool" do
          CreateEcommOrders.manual_add( qaorder, '1' )
          expect( RudiOperations.command_line_all( qaorder ) ).to_not eq 0
        end

        it "books multiple orders via rudi using a command line tool" do
          qaorder.config_list = [ CONFIGFILE_TWO ]
          CreateEcommOrders.api_add( qaorder )
          expect( RudiOperations.command_line_all( qaorder ) ).to eq 0
        end

        it "invoices all outstanding orders via rudi using a command line tool" do
          expect( RudiOperations.command_line_invoice_query_all( qaorder ) ).to eq 0
        end

        it "cancels all outstanding orders via rudi using a command line tool" do
          expect( RudiOperations.command_line_cancel_query_all( qaorder ) ).to eq 0
        end
    end
end
