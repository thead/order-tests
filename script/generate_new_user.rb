#!/usr/bin/env ruby

#
# Generate a new random test user
#

$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'qa_command_line'
require 'create_ecomm_users'

QACommandLine.initialize( 'generating a valid random user', '    This is a QA script for generating a valid random new user' )
exit QACommandLine.process { |o|
  user = CreateEcommUsers.api_add_curl_post( o )

  o.logger.info "Created randomly generated new user: #{user}" if user
  user ? 0:1
}
