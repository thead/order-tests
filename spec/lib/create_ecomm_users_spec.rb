require 'spec_helper'
require 'securerandom'

describe CreateEcommUsers do
    let(:output)   { double('output').as_null_object }
    let(:qalogger) { QALogger.new( LOGFILE, false, LABEL, output ) }
    let(:qaorder)  { QATestEnv.new( qalogger ) }

    context 'add/create users' do
        it "manually adds a user" do
          users = CreateEcommUsers.manual_add( qaorder, 'test_rspec_123@modcloth.com' )
          expect( users.first ).to eq "test_rspec_123@modcloth.com"
        end

        it "manually adds multiple users" do
          users = CreateEcommUsers.manual_add( qaorder, 'test_rspec_123@modcloth.com test_rspec_124@modcloth.com' )
          expect( users.first ).to eq 'test_rspec_123@modcloth.com'
          expect( users.last ).to eq 'test_rspec_124@modcloth.com'
        end

        it "creates a new random user" do
          user = CreateEcommUsers.api_add_curl_post( qaorder )
          expect( user ).to_not be_nil
        end

        it "creates a new explicit user" do
          my_user = SecureRandom.uuid + '@newuser.modcloth.com'
          user = CreateEcommUsers.api_add_curl_post( qaorder, my_user, 'my_password' )
          expect( user ).to eq my_user
        end
    end
end
