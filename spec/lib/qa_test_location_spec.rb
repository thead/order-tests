require 'spec_helper'

describe QATestLocation do

    context 'initialization' do
        it 'generates a default location "stage"' do
          mysite = QATestLocation.new
          expect( mysite.location ).to eq 'stage'
        end

        it 'generates a default data set equal to "stage"' do
          saved = ENV['SQA_ECOMM_DB']
          ENV['SQA_ECOMM_DB'] = 'test'
          mysite = QATestLocation.new
          expect( mysite.data[:SQA_ECOMM_DB] ).to eq ENV['SQA_ECOMM_DB']
          ENV['SQA_ECOMM_DB'] = saved
        end

        it 'generates a custom location' do
          mysite = QATestLocation.new( 'DEV' )
          expect( mysite.location ).to eq 'DEV'
        end

        it 'generates a custom default data set for any custom location' do
          saved = ENV['SQA_ECOMM_DB']
          ENV['SQA_ECOMM_DB'] = 'test'
          mysite = QATestLocation.new( 'DEV' )
          expect( mysite.data[:SQA_ECOMM_DB] ).to eq ENV['SQA_ECOMM_DB']
          ENV['SQA_ECOMM_DB'] = saved
        end

        it 'updates data sets' do
          mysite = QATestLocation.new( 'DEV' )
          mysite.data[:SQA_ECOMM_DB] = 'fred'
          expect( mysite.data[:SQA_ECOMM_DB] ).to eq 'fred'
        end

        it 'stores an env_file' do
          mysite = QATestLocation.new( 'DEV', CONFIGFILE_STAGE)
          expect( mysite.env_file).to eq CONFIGFILE_STAGE
        end
    end
end
