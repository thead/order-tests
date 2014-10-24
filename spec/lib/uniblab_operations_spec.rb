require 'spec_helper'

describe UniblabOperations do
    let(:output)         { double('output').as_null_object }
    let(:qalogger)       { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)        { QATestEnv.new( qalogger ) }

    context 'methods' do
        it "ships/captures all outstanding orders via uniblab using a command line tool" do
          expect( UniblabOperations.uniblab_query_all( qaorder ) ).to eq 0
        end

        it "fails on an invalid order using a command line tool" do
          CreateEcommOrders.manual_add( qaorder, '1' )
          expect( UniblabOperations.uniblab_all( qaorder ) ).to_not eq 0
        end
    end
end
