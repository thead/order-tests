#!/usr/bin/env ruby

#
# Support creation of E-comm orders by finding valid items for an order
#

$LOAD_PATH << File.expand_path('..', __FILE__)
require 'qa_logger'

module FindDBItems
  # Constant for number of items to randomly select from in Ecomm.
  # Some simple experiments shows about half of the items selected
  # in Ecomm are also in stock and part of a valid order in Oracle.
  RANDOM_RANGE = 100

  # Constant for the minimum price and price range on a random item
  RANDOM_PRICE_MIN = 30
  RANDOM_MIN_PRICE_RANGE = 20

  # Inputs orders object and an array of [quantities,random_string] for each random item
  # All selected items will have sufficient quantities in Ecomm/Oracle
  # Returns array of item upc, sku, quantity hashes
  def self.find_random_all( test, random_array = [[1,{}]], repeat = 1 )
    # exclude array keeps the backorder items from being selected
    quantity_hash = {}
    exclude = []
    items_array = []
    repeat.times do |i|
      random_array.each do |quantity, random_hash|
        my_upc,my_sku,my_quantity = self.find_random( test.edb_ro, test.odb_ro, quantity, random_hash, exclude, test.recorder )

        quantity_hash[my_upc] = my_quantity.to_i unless quantity_hash[my_upc]
        quantity_hash[my_upc] -= 1
        exclude.push my_upc unless quantity_hash[my_upc] > 0

        items_array.push Hash[ 'upc' => my_upc, 'sku' => my_sku, 'quantity' => quantity ]
      end
    end
    test.logger.debug "Found items array is: #{items_array}"
    return items_array
  end

  # Finds a random item valid in both Ecomm and Oracle for the quantity given
  # Takes an optional exclude array of item upc's to exclude from consideration
  # Returns both the upc and sku of the item selected
  def self.find_random( edb, odb, quantity = 1, random_hash = {}, exclude = [], recorder = QALogger.new )
    return nil, nil unless random_hash

    # SQL exclude string for any item upcs in the optional exclude array
    if exclude.length > 0
      my_edb_exclude = 'AND upc NOT IN (' + exclude.join(',') + ')'
    else
      my_edb_exclude = ''
    end

    # Defaults for random item optional requirements
    my_edb_tax = ''
    my_edb_vintage = ''
    my_edb_over_value = RANDOM_PRICE_MIN
    my_edb_under_value = nil
    my_edb_under_price = ''

    random_hash.each_key do |key|
      # We are not worrying about duplicate/contradictory/invalid keys for now
      case key
      # Over a minimum price is default and under is not for the following reason:
      #    As we sort based on quantity, without a minimum threshold all the cheapo
      #    items in large quantities would dominate the results, which is not what we
      #    normally desire in a random order item.
      when 'over'
        my_edb_over_value = random_hash['over']

        # If over value is really high, give a minimum RANDOM_MIN_PRICE_RANGE range for under value
        min_under_value = my_edb_over_value + RANDOM_MIN_PRICE_RANGE
        if my_edb_under_value and min_under_value > my_edb_under_value
          my_edb_under_value = min_under_value
          my_edb_under_price = "AND products.price < #{my_edb_under_value}"
        end
      when 'tax'
        my_edb_tax =  random_hash['tax'] ? 'AND is_taxable = 1': 'AND is_taxable = 0'
      # Under will primarily be used for Savvy Saver $4 shipping orders
      when 'under'
        my_edb_under_value = random_hash['under']
        my_edb_under_price = "AND products.price < #{my_edb_under_value}"

        # If under value is really low, give a minimum RANDOM_MIN_PRICE_RANGE range for over value
        min_over_value = my_edb_under_value - RANDOM_MIN_PRICE_RANGE
        if min_over_value < my_edb_over_value
          my_edb_over_value = min_over_value < 0 ? 0 : min_over_value
        end
      when 'vintage'
        my_edb_vintage = random_hash['vintage'] ? 'AND is_vintage = 1': 'AND is_vintage = 0'
      end
    end

    # Construct straight SQL so testers/devs can directly steal the query for other purposes if need be
    my_edb_query_str = <<EOF
  SELECT sku, upc, inventory_units_on_hand_count, product_id, products.price, is_vintage, is_taxable
    FROM variants, products
   WHERE product_id = products.id AND
         products.price > #{my_edb_over_value} AND
         active = 1 AND
         ships_usa_only = 0 AND
         in_stock = 1 AND
         is_preorder = 0 AND
         is_discontinued = 0 AND
         is_coming_soon = 0 AND
         inventory_units_on_hand_count >= #{quantity}
         #{my_edb_exclude}
         #{my_edb_tax}
         #{my_edb_vintage}
         #{my_edb_under_price}
ORDER BY inventory_units_on_hand_count DESC LIMIT #{RANDOM_RANGE}
EOF

    recorder.logger.debug "Ecomm sql line: \n#{my_edb_query_str}"

    # If we have a crazy request that can not be satisfied, like vintage item quantity 20, better to explode
    # as we will not have a viable order regardless. Random orders should have simple requirements, so I'll
    # ignore pathological cases defense

    # Run query and hash ecomm upc values to sku
    my_edb_query = edb[ my_edb_query_str ]
    my_upc_to_sku = my_edb_query.to_hash(:upc, :sku)

    # Given the Ecomm top RANDOM_RANGE item listings, pick a random one also found in quantity in Oracle
    # Yes, the Ecomm upc == the Oracle sku, it was not a cutnpaste dsylexia error
    my_sku = my_edb_query.all.map{|r| r[:upc]}.join(',')
    my_odb_query_str = <<EOF
SELECT * FROM (
    SELECT sku, quantity_on_hand
      FROM xxmc.xxmc_item_onhand
     WHERE sub_inventory = 'PGHFC' AND
           sku IN ( #{my_sku} ) AND
           quantity_on_hand >= #{quantity}
     ORDER BY dbms_random.value )
WHERE rownum = 1
EOF
    recorder.logger.debug "Oracle sql line: \n#{my_odb_query_str}"

    odb_item = odb.exec(my_odb_query_str).fetch()
    recorder.logger.debug "Random item winner is #{odb_item}"
    if odb_item
      return_upc = odb_item.first
      return_sku = my_upc_to_sku[return_upc]
      return_quantity = odb_item.last
    else 
      return_upc = nil
      return_sku = nil
      return_quantity = 0
    end

    return return_upc, return_sku, return_quantity
  end
end
