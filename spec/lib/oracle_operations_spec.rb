require 'spec_helper'

describe QAOracle do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }
    let(:my_order) {
      qaorder.config_list = [ CONFIGFILE_BASIC ]
      CreateEcommOrders.api_add( qaorder )
      RudiOperations.command_line_all( qaorder )
      qaorder.data.first
    }

    context 'methods' do
        it "validates default querying an order" do
          odb = QAOracle.db_connect()
          num_rows = odb.exec("select action from xxmc.xxmc_salesorder_headers_v2 where order_number = #{my_order} AND action = 'N'") do |record|
            expect( record[0] ).to eq 'N'
          end
          expect( num_rows ).to eq 1
        end

        it "validates querying an order" do
          odb = QAOracle.db_connect(qaorder.location)
          num_rows = odb.exec("select action from xxmc.xxmc_salesorder_headers_v2 where order_number = #{my_order} AND action = 'N'") do |record|
            expect( record[0] ).to eq 'N'
          end
          expect( num_rows ).to eq 1
        end

        it "validates querying an order as an update user" do
          odb = QAOracle.db_connect(qaorder.location, true)
          num_rows = odb.exec("select action from xxmc.xxmc_salesorder_headers_v2 where order_number = #{my_order} AND action = 'N'") do |record|
            expect( record[0] ).to eq 'N'
          end
          expect( num_rows ).to eq 1
        end
    end
end
