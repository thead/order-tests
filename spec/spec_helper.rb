$LOAD_PATH << File.expand_path('../lib', __FILE__)
$LOAD_PATH << File.expand_path('../../lib', __FILE__)
$LOAD_PATH << File.expand_path('../', __FILE__)

require 'qa_logger'
require 'qa_test_location'
require 'qa_test_env'
require 'create_ecomm_orders'
require 'create_ecomm_users'
require 'create_oracle_shipments'
require 'validate_ecomm_orders'
require 'validate_oracle_orders'
require 'validate_hj_orders'
require 'validate_oracle_shipments'
require 'compare_db_orders'
require 'find_db_items'
require 'find_orders'
require 'ecomm_operations'
require 'ecomm_updates'
require 'oracle_operations'
require 'oracle_programs'
require 'rudi_operations'
require 'uniblab_operations'

# Variables for creating a static log file name
LOGDIR  = 'log'
LOGFILE = "#{LOGDIR}/rspec.log"
LABEL   = 'RSpec test'

CONFIGDIR = 'config'
CONFIGFILE_BASIC = "#{CONFIGDIR}/order_api_post_basic.json"
CONFIGFILE_TWO = "#{CONFIGDIR}/order_api_post_two.json"
CONFIGFILE_RANDOM = "#{CONFIGDIR}/order_api_post_random_test.json"
CONFIGFILE_SKU = "#{CONFIGDIR}/order_api_post_sku.json"
CONFIGFILE_UPC = "#{CONFIGDIR}/order_api_post_upc.json"
CONFIGFILE_USER = "#{CONFIGDIR}/order_api_post_user.json"

CONFIGFILE_STAGE = "#{CONFIGDIR}/stage.sh"

# Order variable to chain tests together
$order = nil

RSpec.configure do |config|
  config.before(:all) do
    Dir.mkdir( LOGDIR ) if not File::exists?( LOGDIR )
  end
  config.before(:each) do
    File.delete( LOGFILE ) if File::exists?( LOGFILE )
  end
end
