#!/usr/bin/env ruby

#
# Support creation of E-comm orders
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'create_ecomm_users'
require 'ecomm_queries'
require 'find_db_items'

require 'json'
require 'curb'

# Methods return the number of fatal failures encountered
module CreateEcommOrders
  def self.manual_add( test, data_string = nil )
    unless data_string
      print 'MANUAL STEP: create one or more order numbers and input space separated: '
      data_string = $stdin.gets.chomp
    end
    test.data += data_string.split
    test.logger.info "The orders have been manually updated to include #{data_string}"
    return 0
  end

  # Process all new order config files and process resulting json data
  def self.api_add( test )
    combined_jsons = []
    test.config_list.each do |config_file|
      my_jsons = self.api_add_config_file( test, config_file )
      my_jsons.each do |new_order|
        combined_jsons << new_order
      end
    end

    return self.api_add_json(test, combined_jsons)
  end

  # Process a single new order config file, return json or nil on error
  def self.api_add_config_file( test, file )
    unless File.exists?(file)
      test.logger.error "Config file #{file} does not exist"
      return nil
    end

    test.logger.debug "Loading config file #{file}"
    my_jsons = JSON.load( File.open(file, 'r') )
    if (not my_jsons) or (my_jsons.length == 0)
      test.logger.error "Contents of config file #{file} could not be loaded"
      return nil
    end

    test.logger.debug "Returning json data from config file #{file}:\n #{my_jsons}"
    return my_jsons
  end

  # json hash can contain one or more order requests
  def self.api_add_json( test, my_jsons )
    # If upc's are present, add equiv. sku
    return 1 if self.add_sku_for_upc( test, my_jsons) != 0

    # Map how many find-item entries exist
    my_random_items = self.api_add_find_random_items( my_jsons )
    # If random items requested, find them
    if my_random_items.length > 0
      my_found_items = FindDBItems.find_random_all( test, my_random_items.map{|item| [item['quantity'], item['find-item']]}, test.repeat )
    end

    # Count how many new-user entries exist
    new_users_count = self.count_new_users( my_jsons ) * test.repeat

    # If new-users requested, generate them
    my_created_users = []
    new_users_count.times do |i|
      my_created_users.push CreateEcommUsers.api_add_curl_post( test )
    end

    # Update json for random item and new user requests
    error_count = 0
    test.repeat.times do |i|
      if my_random_items.length > 0
        return 1 if self.api_add_replace_random_items(my_random_items, my_found_items, test.recorder) != 0
      end
      if new_users_count > 0
        return 1 if self.api_add_replace_new_users(my_jsons, my_created_users, test.recorder) != 0
      end

      # Send updated orders to the API
      my_jsons.each do |my_json|
        error_count += self.api_add_curl( test, my_json )
      end
    end
    return error_count
  end

  # If there are upc's in the json, add sku
  def self.add_sku_for_upc( test, my_jsons )
    my_jsons.each do |my_json|
      my_json['items'].each do |my_item|
        if my_item['upc']
          sku = QAEcommQuery.get_field(test.edb_ro, my_item['upc'], 'sku', test.recorder)
          my_item['sku'] = sku if sku
        end
      end
    end
    return 0
  end

  # Find and collect any random items
  def self.api_add_find_random_items( my_jsons )
    my_random_items = []
    my_jsons.each do |my_json|
      my_json['items'].each do |item|
        my_random_items.push item if item['find-item']
      end
    end
    return my_random_items
  end

  # Count any new user requests
  def self.count_new_users( my_jsons )
    my_count = 0
    my_jsons.each do |my_json|
      my_count += 1 if my_json['account'] && my_json['account']['new-user']
    end
    return my_count
  end

  # Replace random items with found items
  def self.api_add_replace_random_items(my_random_items, my_found_items, recorder)
    my_random_items.each do |item|
      # Sanity check, really should not be needed as data should be ordered
      # If find_random_all didn't find an item, don't update
      my_item = my_found_items.shift
      if my_item['sku'] and item['find-item'] and (my_item['quantity'] == item['quantity'])
        item['sku'] = my_item['sku']
        #item.delete('find-item')
      else
        recorder.logger.error "Failed to find an appropriate order item for #{item}"
        return 1
      end
    end
    return 0
  end

  # Replace new users
  def self.api_add_replace_new_users(my_jsons, my_new_users, recorder)
    my_jsons.each do |my_json|
      if my_json['account']['new-user']
        my_json['account']['email'] = my_new_users.shift
      end
    end
    return 0
  end

  # Post and get verify given json data
  def self.api_add_curl( test, my_post_json )
    # Post the orders
    my_order = self.api_add_curl_post( test, my_post_json )
    return 1 unless my_order

    # Verify order post data against an order get
    my_get_json = self.api_add_curl_get( test, my_order )
    return 1 unless my_get_json

    success = true
    for index in ['is_gift', 'shipping_address', 'billing_address', 'shipping_method_code']
      my_success = (my_post_json[index] == my_get_json[index])
      test.logger.error "#{index} does not match between order API post (#{my_post_json[index]}) and get (#{my_get_json[index]})" unless my_success
      success &= my_success
    end
    my_success = (my_post_json['account']['email'] == my_get_json['account']['email'])
    test.logger.error "account email does not match between order API post (#{my_post_json['account']}) and get (#{my_get_json['account']})" unless my_success
    success &= my_success
    my_success = (my_post_json['items'].length == my_get_json['items'].length)
    test.logger.error "number of items does not match between order API post (#{my_post_json['items']}) and get (#{my_get_json['items']})" unless my_success
    success &= my_success

    test.data << my_order if success
    return success ? 0 : 1
  end

  def self.api_add_curl_post( test, my_post_json )
    # Convert hash to json string
    my_json_string = my_post_json.to_json()
    test.logger.debug "api_add_post my_json input: #{my_json_string}"

    # Invoke curl post
    my_url = test.location.data[:SQA_ECOMM_API_SERVER_URL]
    http = Curl::Easy.http_post( my_url + '/services/automation/orders', my_json_string) do |curl|
      curl.headers['Content-Type'] = 'application/json'
    end
    test.logger.debug "response code from order API create post: #{http.response_code}"
    test.logger.debug "response body from order API create post: #{http.body_str}"

    # Check both response code and output
    success = (http.response_code == 201)
    if success
      parsed_response = http.body_str.scan(/services\/automation\/orders\/(\d+)$/).first
      success = (parsed_response != nil)
    end

    # If post failed, bail
    unless success
      test.logger.error "#{http.body_str}"
      return nil
    end
    return parsed_response.first
  end

  def self.api_add_curl_get( test, my_order )
    my_url = test.location.data[:SQA_ECOMM_API_SERVER_URL]
    http = Curl::Easy.http_get( my_url + "/services/automation/orders/#{my_order}") do |curl|
      curl.headers['Content-Type'] = 'application/json'
    end
    test.logger.debug "response code from order API create get: #{http.response_code}"
    test.logger.debug "response body from order API create get: #{http.body_str}"

    # If get failed, bail
    success = (http.response_code == 200)
    unless success
      test.logger.error "#{http.body_str}"
      return nil
    end

    # Return the parsed get output data
    return JSON.parse( http.body_str )
  end
end
