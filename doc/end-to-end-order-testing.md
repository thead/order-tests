End to end order testing for Stage
-----------------------
Intro

First you should update your service-qa repository and initialize your test environment:

1. do a `git pull` on your `service-qa` branch
2. You will need SSH keys to access the ecomm system for the given test environment (currently needed to access the rudi/uniblab server)
  * Add any needed SSH keys to ssh-agent (`ssh-add ~/.ssh/<key>`)
3. start vagrant if you need to: `vagrant up`
4. `vagrant ssh` 
5. vagrant@service-qa:~$ `cd /vagrant`
6. vagrant@service-qa:/vagrant$ `source config/stage.sh`

Those steps are really only needed before a testing session to insure you are running with the latest test code.

To generate an end to end test for a random single item, new user order, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w`

and just let that run. With `-w` enabled, warnings are non-fatal and colored yellow instead of red like true failures. To get a list of all available arguments, testing steps and tests, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -h`

---------------------
Fraud test

The same environment can be used to perform end to end testing on a fraud canceled order:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --test fraud -w`

As the operations and testing steps needed for a fraud order are slightly different, the `--test` argument can be employed to use a defined set of testing steps.

The testing steps used for any type of test can be seen by:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --test <TEST> -h`

which displays the usage help for that test, including that tests defined steps. The currently defined tests are default, fraud, gift and watch.

---------------------
Gift test

The gift test is not fully automated and includes a manual testing steps, which it prompts you to perform.

To initiate a gift certificate test, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --test gift -w`

At this point, the test will prompt you for an order number. You will need to go to the stage ecomm server and manually create a gift certificate purchase order. When you have the order number, enter that number at the prompt and the rest of the test steps will run without additional manual intervention required. This manual step is required as we currently do not have an automated method to generate a gift certificate order.

---------------------
Watch test (and variants)

The watch tests were created to follow orders in one of the test environments, including prod, without forcibly changing the flow of the order through the system. It simply watches and validates data as the order progresses. If no order is available to watch when executed, the test ends immediately but without failure.

To initiate a watch test, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --test watch -w`

The test will look for a new order that has passed the 1 hour delay but has yet to be booked. This order will then be followed through the entire order lifecycle, including fulfillment in high jump.In production, this will be a day or more. As this time frame will be impractical in many cases, there are additional watch variants:

- watch_new : Find a newly created order and watch it until it reaches fulfillment/high jump
- watch_gift : Find a newly created gift certificate order and watch it through invoicing
- watch_shipped : Find a newly Agile shipped order and watch it through invoicing
- watch_fraud : Find a newly marked fraud cancelled order and watch it through invoicing

---------------------
Testing other types of orders

To test an order that is not a simple single random item, new user order, you can reference one of the available order json files found in the /config directory. For example:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w config/order_api_post_multi.json`

This will run the default end to end order test on an order with multiple random items and a new user. There are a number of pre-defined order json files in /config and /config/test that you can use. You can also create your own order json files in /config/custom to make any supported custom order file you wish.

You may also list more than one order json file in your command line. Each included order json file will generate the requested order(s) and the rest of the end to end testing steps will be applied to all created orders.

---------------------
Testing multiple orders at once

To test multiple random single item, new user orders at the same time, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w --repeat 10`

This will create 10 unique orders and test them end to end. Make sure to use the `-w` warning option when working with largish numbers of orders as certain data fields related to last update or updated by scheduled oracle programs will fail strict testing. Consider your options before generating groups of more than 100 orders at a time as the time between testing steps for large numbers of orders can get long. The `--repeat` option can be combined with any of the above listed tests or test options.

---------------------
Replacing end to end testing step(s)

Often one needs to run a test that is a slight variant to one of the defined tests. In such cases, `--# STEP` arguments can be used to replace a specific step in a test.

For example, to end to end test a manually created custom order that fully scratches the first item, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w --1 CreateManual --12 FakeHJCancelOne`

---------------------
Creating a completely custom test

If you need to run a unique test, or just part of a test, you can use the `--custom` argument to completely redefine the testing steps to perform.

Here is an example of someone taking an existing order awaiting HJ wave/pick/sort/ship and fakes that operation out, leaving the order to complete without intervention:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w --custom 'CreateManual FakeHJ WaitHJShippedPoll VerifyOracleAgileShip'`

As the CreateManual step simply asks for an order, you can give it an existing order number instead of creating a new one.

---------------------
On failure and on success testing step

If you need to execute one additional step if your test fails or succeeds, you can use the `--onfailure` and `--onsuccess` argument respectively with a given step to execute.

Here is an example of someone running a watch test that should generate a new order only if the watch test succeeds:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --test watch --onsuccess CreateAuto -aw`

By default, no additional testing step is executed on success or failure.

---------------------
Order regression tests

In the /config/test directory are a set of order regression testing json files. Currently only some of the 28 defined regression orders are supported, the rest being prefixed by 'ns-' for not supported.

To run the currently supported order regression tests, execute:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb -w config/test/[0-9]*.json`

This command will pick up all json files in /config/test/ that start with a number 0-9.

---------------------
Rspec end to end testing

Two rspec files are available for running an order end to end testing cycle. Execute either or both of the below commands to rspec test a standard and/or fraud order end to end:

- vagrant@service-qa:/vagrant$ `bundle exec rspec --color --format doc spec/lib/end_to_end_orders_spec.rb`
- vagrant@service-qa:/vagrant$ `bundle exec rspec --color --format doc spec/lib/end_to_end_fraud_orders_spec.rb`

