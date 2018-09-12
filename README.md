# monitor.lua

This script is a little WIP monitor for my servers. It tests ports are open and respond correctly. When one test fails it makes a report and handle it with a reporter, ATM only one exists and it builds and executes an HTTP request with the report in a field. I use it to send myself SMS’s.

`monitor.lua` uses a config file to know what to test, and a state file so that it remembers the previous result of tests and don’t send you reports every time the tests run. It will report you that a test in back to a positive result.

Run this script with the `-batch` option to run the tests (in a cron for example), without option to list the currently failing tests, and with `-all` to list all data available about all tests.

## Arguments

`./monitor.lua [-v] [-c config_file] { -batch [-console-report] | [-all] [-json] | -test-reporters }`

Without any option, the command will display currently failing tests.

* `-c config_file` use a specific configuration file, instead of the default `~/.config/monitor.config.lua`
* `-batch` runs the tests, it is meant to be used in the cron command
* `-console-report` overrides configured reporters and only reports to console for this run
* `-all` display all tests states, even tests that are ok
* `-json` output the tests states as a serialized json map
* `-v` verbose mode, script says what it’s doing
* `-test-reporters` sends a test message to all configured reporters

