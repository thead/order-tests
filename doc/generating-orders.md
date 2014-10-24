Adapted from email by Thomas Head 2014-07-11
Updated by Thomas Head 2014-08-13

Creating load for Stage
-----------------------

Creating a simulated order load on stage.

First you should update your service-qa repository and initialize your test environment:

1. do a `git pull` on your `service-qa` branch
2. You will need SSH keys to access the ecomm system for the given test environment (currently needed to access the rudi/uniblab server)
  * Add any needed SSH keys to ssh-agent (`ssh-add ~/.ssh/<key>`)
3. start vagrant if you need to: `vagrant up`
4. `vagrant ssh` 
5. vagrant@service-qa:~$ `cd /vagrant`
6. vagrant@service-qa:/vagrant$ `source config/stage.sh`

Those steps are really only needed before a testing session to insure you are running with the latest test code.

To generate a constant stream of orders, execute:

- vagrant@service-qa:/vagrant$ `while true; do script/CreateAuto.rb; done`

and just let that run. It should create a new random order with a new user approximately every 10 seconds. Let it run maybe 2 hours before starting a dry run and we will have an assortment of single item order either new or just pushed to fullfillment. You can stop this order creation by simply pressing control-c. It can be restarted as needed.

To fake HJ shipping of orders awaiting HJ wave/pick/sort/ship, execute:

- vagrant@service-qa:/vagrant$ `while true; do ./qa_order_test.rb --custom 'FindUnshippedOrder FakeHJ' --repeat 10; sleep 60; done`

which will process up to 10 outstanding orders sitting in the order master table that have not been shipped in a full day and then sleep for a minute. This command, like the one above, can be stopped and restarted as needed.

---------------------

The same environment can be used to create and book via rudi a single order if desired:

- vagrant@service-qa:/vagrant$ `script/CreateAuto.rb`
- vagrant@service-qa:/vagrant$ `script/ClearHourDelay.rb <ORDER>`
- vagrant@service-qa:/vagrant$ `script/BookRudi.rb <ORDER>`
- vagrant@service-qa:/vagrant$ `script/InvokeOracleSO.rb <ORDER>`

You can acheive the exact same results using qa_order_test.rb:

- vagrant@service-qa:/vagrant$ `./qa_order_test.rb --custom 'CreateAuto ClearHourDelay BookRudi InvokeOracleSO' --repeat 1`

The `--repeat 1` argument is not needed, but is included so you can use values other than `1` to generate multiple orders at one time if desired.

If you wish to push several orders farther, you must either manually wave/pick/sort/ship these orders in HighJump, or fake the HighJump operations like so:

- vagrant@service-qa:/vagrant$ `script/FakeHJ.rb <ORDER>`
- vagrant@service-qa:/vagrant$ `script/WaitHJShipped.rb <ORDER>`

Orders that have made it this far can move through uniblab ship, ecomm capture services and rudi invoicing steps without further intervention.
