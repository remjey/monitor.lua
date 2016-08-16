# monitor.lua

This script is a little WIP monitor for my servers. It tests ports are open and respond correctly. When one test fails it makes a report and handle it with a reporter, ATM only one exists and it builds and executes an HTTP request with the report in a field. I use it to send myself SMS’s.

`monitor.lua` uses a config file to know what to test, and a state file so that it remembers the previous result of tests and don’t send you reports every time the tests run. It will report you that a test in back to a positive result.

Run this script with the `-batch` option to run the tests (in a cron for example), without option to list the currently failing tests, and with `-all` to list all data available about all tests.
