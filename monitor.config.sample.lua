
return {
  -- This is a list of websites that we will try to contact in HTTP(S) in batch mode.
  -- If less than two of the websites do respond, the monitor script won’t execute.
  -- This list can be empty, in this case the script will always run the tests.
  test_connection_with_hosts = {
    "http://google.com", "http://free.fr", "https://facebook.com", "https://microsoft.com",
  },
  states_filename = nil, -- use default ~/.local/monitor.lua.state
  remind_period = nil, -- when a test consistently fails, remind the failure after this period in seconds (default 8 hours)
  monitor = {
    -- This is a connect test. The script will connect to the specified host:port
    -- It will then send the content of the `send` entry if not empty
    -- and read a line from the socket and match the regex in `match_response`
    -- against it.
    {
      -- Test that the SSH server is up
      id = "example.com SSH test" -- optional, generated if missing. IDs must be unique
      type = "connect",
      host = "example.com",
      port = 22,
      match_response = "^SSH%-", -- optional, is a lua regex
    },
    {
      -- Check an HTTP response status
      type = "connect",
      host = "example.com",
      port = 80,
      send = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n", -- optional
      match_response = "^HTTP/1.1 200 ", -- optional
    },
    {
      -- Make an http request and check the status and body
      type = "http", -- this type of test also supports https
      url = "http://example.com/index.html",
      check_status = 200, -- optional
      match_response = 'Welcome to example.com', -- optional
      consecutive_failures_threshold = 4, -- optional, only report after 4 consecutive failures (default 1)
    },
  },
  -- Once the tests have been run, a number of reports have been created and will
  -- be fed in the report modules below.
  report = {
    {
      -- This module builds an HTTP request for each report and executes it
      type = "http",
      method = "GET", -- default GET, can also be POST
      url = "https://example.com/send-an-sms",
      report_mode = "short", -- use the short report (default and only mode supported)
      report_param = "msg", -- this parameter will receive the report
      report_prefix = "Monitor: ", -- this optional string is added at the beginning of the report
      other_params = {
        -- Additionnal parameters for the HTTP request
        user = "example-user",
        pass = "password",
      },
      -- In POST mode, the (default) `form` encoding will encode the data as
      -- application/x-www-form-urlencoded, and `json` will encode in application/json.
      encoding= "form",
    },
    {
      -- This report module just writes the reports on the console
      type = "console",
    },
  }
}
