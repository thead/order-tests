require 'spec_helper'

describe FindDBItems do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }

    context 'methods' do
        it "finds a single random item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 1
        end

        it "finds a single random item in quantity" do
          found_list = FindDBItems.find_random_all( qaorder, [[2, {}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 2
        end

        it "finds a single random vintage item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {vintage: true}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity']).to eq 1
        end

        it "finds a single random taxable item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {tax: true}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 1
        end

        it "finds a single random tax free item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {tax: false}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 1
        end

        it "finds a single random under $50 item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {under: 50}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 1
        end

        it "finds a single random over $90 item" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, {over: 90}]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.first['quantity'] ).to eq 1
        end

        it "fails to find an invalid single random" do
          found_list = FindDBItems.find_random_all( qaorder, [[1, nil]] )
          expect( found_list.length ).to eq 1

          expect( found_list.first['upc'] ).to be_nil
          expect( found_list.first['sku'] ).to be_nil
        end

        it "finds multiple unique random items" do
          found_list = FindDBItems.find_random_all( qaorder, [[2, {}],[1, {}]] )
          expect( found_list.length ).to eq 2

          expect( found_list.first['upc'] ).to_not be_nil
          expect( found_list.first['sku'] ).to_not be_nil

          expect( found_list.last['upc'] ).to_not be_nil
          expect( found_list.last['sku'] ).to_not be_nil

          expect( found_list.first['upc'] ).to_not eq found_list.last['upc']
          expect( found_list.first['sku'] ).to_not eq found_list.last['sku']

          expect( found_list.first['quantity'] ).to eq 2
          expect( found_list.last['quantity'] ).to eq 1
        end
    end
end
