#!/usr/bin/env ruby

#
# Class to support creation of E-comm users
#

require 'securerandom'
require 'curb'
require 'json'

# Create an Ecomm user/users
module CreateEcommUsers
  def self.manual_add( order, data_string = nil )
    unless data_string
      print 'MANUAL STEP: create one or more Ecomm users and input email addresses space separated: '
      data_string = $stdin.gets.chomp
    end
    users = data_string.split
    order.logger.info "The users have been manually updated to include #{data_string}"
    return users
  end

  # Return new user email or nil on failure
  def self.api_add_curl_post( test, user = nil, password = nil )
    user = SecureRandom.uuid + '@newuser.modcloth.com' unless user
    password = 'test' unless password

    my_json_hash = { email: user, password: password }

    # Convert hash to json string
    my_json_string = my_json_hash.to_json()
    test.logger.debug "api_add_curl_post json input: #{my_json_string}"

    # Invoke curl post
    my_url = test.location.data[:SQA_ECOMM_API_SERVER_URL]
    http = Curl::Easy.http_post( my_url + '/services/automation/accounts', my_json_string) do |curl|
      curl.headers['Content-Type'] = 'application/json'
    end
    test.logger.debug "response code from account API create post: #{http.response_code}"
    test.logger.debug "response body from account API create post: #{http.body_str}"

    if http.response_code == 201
      return user
    else
      return nil
    end
  end
end
