require 'spec_helper'

describe QATestEnv do
    let(:output)         { double('output').as_null_object }
    let(:qalogger)       { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)        { QATestEnv.new( qalogger ) }

    context 'initialization' do
        it 'generates an empty data list' do
          mytest = QATestEnv.new( qalogger )
          expect( mytest.data ).to be_empty
        end

        it 'stores a recorder object' do
          mytest = QATestEnv.new( qalogger )
          expect( mytest.recorder ).to eq qalogger
        end

        it 'stores a test location' do
          mysite = QATestLocation.new( 'DEV' )
          mytest = QATestEnv.new( qalogger, mysite )
          expect( mytest.location.location ).to eq 'DEV'
        end

        it 'stores a config_list' do
          mytest = QATestEnv.new( qalogger, QATestLocation.new, [ CONFIGFILE_BASIC ] )
          expect( mytest.config_list ).to eq [ CONFIGFILE_BASIC ]
        end

        it 'stores a default repeat value' do
          mytest = QATestEnv.new( qalogger )
          expect( mytest.repeat ).to eq 1
        end

        it 'stores a repeat value' do
          mytest = QATestEnv.new( qalogger, QATestLocation.new, nil, 5 )
          expect( mytest.repeat ).to eq 5
        end
    end
end
