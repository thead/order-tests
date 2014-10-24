require 'spec_helper'

describe QALogger do
    let(:output)         { double('output').as_null_object }
    let(:qalogger)       { QALogger.new( LOGFILE, false, LABEL, output )  }
    let(:qalogger_debug) { QALogger.new( LOGFILE,  true, LABEL, output )  }

    context 'initialization' do
        it 'generates a start message' do
          output.should_receive(:print).with(/\[INFO \] .* :: Starting #{LABEL}, log file #{LOGFILE}\n/)
          qalogger
        end

        it 'does not enable debugging by default' do
          expect( qalogger.logger.level ).to be Log4r::INFO
        end

        it 'generates a debug message when debugging is enabled' do
          output.should_receive(:print).with(/\[INFO \] .* :: Starting .*\n/).ordered
          output.should_receive(:print).with(/\[DEBUG\] .* :: Debugging is enabled\n/).ordered
          qalogger_debug
        end

        it 'generates a log file' do
          qalogger
          expect( File::exists?( LOGFILE ) ).to be_true
        end

        it 'creates a default logger' do
          qalogger_default = QALogger.new
          expect( qalogger_default.logfile_name ).to be_nil
          expect( qalogger_default.label ).to be_nil
          expect( qalogger_default.logger.level ).to be Log4r::INFO
        end
    end

    context 'summary' do
        it 'generates a summary message' do
          output.should_receive(:print).with(/\[INFO \] .* :: Starting .*\n/).ordered
          output.should_receive(:print).with(/\[SUMMARY\] RESULT: #{LABEL} .*PASSED.* -- Execution time was .* seconds -- Log file log\/rspec.log\n/).ordered
          qalogger.summary
        end
    end

    context 'methods' do
        it 'enables debugging' do
          qalogger.debug( true )
          expect( qalogger.logger.level ).to be Log4r::DEBUG
        end

        it 'passes a successful logged step' do
          qaorder = QATestEnv.new( qalogger )
          qalogger.logged_step( qaorder, 'Passing step') { 0 }
          expect( qalogger.success ).to be_true
        end

        it 'fails a failing logged step' do
          qaorder = QATestEnv.new( qalogger )
          qalogger.logged_step( qaorder, 'Failing step') { 2 }
          expect( qalogger.success ).to be_false
        end
    end
end
