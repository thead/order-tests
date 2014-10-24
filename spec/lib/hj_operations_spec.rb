require 'spec_helper'

describe QAHighjump do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }

    context 'methods' do
        it "validates a DB connection" do
          expect( qaorder.hjdb_ro.active? ).to be true
        end

        it "validates querying orders" do
          result = qaorder.hjdb_ro.execute( 'SELECT TOP 1 * from t_al_host_order_master;')
          result.each
          expect( result.affected_rows ).to eq 1
        end

        it "validates querying orders as an update user" do
          result = qaorder.hjdb_rw.execute( 'SELECT TOP 1 * from t_al_host_order_master;')
          result.each
          expect( result.affected_rows ).to eq 1
        end
    end
end
