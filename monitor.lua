#!/usr/bin/env lua

-- Copyright (c) 2016 Jérémy Farnaud

local socket = require"socket"
socket.url = require"socket.url"
local http = require"socket.http"
local https = require"ssl.https"
local mime = require"mime"

local conf_filename = os.getenv("HOME") .. "/.config/monitor.config.lua"

local batch = false
local show_all = false
local show_json = false

while #arg > 0 do
  local a = table.remove(arg, 1)
  if a == "-batch" then batch = true
  elseif a == "-c" then conf_filename = table.remove(arg, 1)
  elseif a == "-all" then show_all = true
  elseif a == "-json" then show_json = true
  elseif a == "-h" then print(table.concat{ arg[0], " [-c config_file] { -batch | [-all] [-json] }" })
  else error("invalid argument: " .. tostring(a))
  end
end

local conf = loadfile(conf_filename)()
if not conf then error("could not load configuration file: " .. tostring(conf_filename)) end

local states_filename = conf.states_filename or (os.getenv("HOME") .. "/.local/monitor.state.lua")
local states = (loadfile(states_filename) or function () return {} end)()

if not batch then
  if show_json then
    local r
    if show_all then
      r = states
    else
      r = {}
      for test_id, state in pairs(states) do
        if not state.online then r[test_id] = state end
      end
    end
    io.write(require"cjson".encode(r))
  else
    for test_id, state in pairs(states) do
      if not state.online or show_all then
        io.write("Test ID:      ", test_id, "\n")
        io.write("Last attempt: ", os.date("%c", state.last_attempt), "\n")
        io.write("Test result:  ", state.online and "ok" or "failed", "\n")
        if #state.reports > 0 then
          io.write("Lastest reports:\n")
          local start = math.max(1, #state.reports - 2)
          for i = #state.reports, start, -1 do
            local r = state.reports[i]
            io.write("  Time:    ", os.date("%c", r.time), "\n")
            io.write("  Result:  ", r.online and "ok" or "failed", "\n")
            io.write("  Message: ", r.short, "\n\n")
          end
        else
          io.write("\n")
        end
      end
    end
  end
  os.exit(0)
end

-- Check that internet works using a few different sites

local working_count = 0
local tested = 0
for _, site in ipairs(conf.test_connection_with_hosts) do
  tested = tested + 1
  local url = "http://" .. site .. "/"
  local r, s, rh = http.request(url)
  if r and s == 200 then
    working_count = working_count + 1
    if working_count >= 2 then break end
  end
end

if working_count < 1 and tested > 0 then
  -- We’re not sure we are really connected, so let’s quit
  os.exit(1)
end

function httpqs(url)
  if url:find"^https:" then return https end
  return http
end

local tests = {}

function check_content(item, value)
  if type(value) ~= "string" or type(item.match_response) ~= "string" then return false end
  return value:find(item.match_response) ~= nil
end

function tests.connect(item)
  local report = {
    online = false,
    test_id = item.id or table.concat({ item.type, item.host, item.port }, "|"),
  }

  local s = socket.tcp()
  s:settimeout(item.timeout or 10)
  local ok, err = s:connect(item.host, item.port)
  if not ok then
    report.short = table.concat{ "connect to ", item.host, ":", item.port, " failed" }
    return report
  end

  if item.send then
    local ok, err = s:send(item.send)
    if not ok then
      report.short = table.concat{ "send to ", item.host, ":", item.port, " failed" }
      return report
    end
  end

  if item.match_response then
    local s, err = s:receive("*l")
    if not s then
      report.short = table.concat{ "receive from ", item.host, ":", item.port, " failed" }
      return report
    end

    if not check_content(item, s) then
      report.short = table.concat{ "unexpected response from ", item.host, ":", item.port }
      return report
    end
  end

  s:close()
  report.online = true
  report.short = table.concat({ item.host, ":", item.port, " is back to normal" })
  return report
end

function tests.http(item)
  local req = {
    method = item.method or "GET",
    url = item.url,
  }

  local report = {
    online = false,
    test_id = item.id or table.concat({ item.type, req.url, req.method }, "|")
  }

  local sinkdata = {}
  if req.method == "POST" or req.method == "PUT" then
    req.source = coroutine.wrap(function () coroutine.yield(item.body or "") end)
  elseif req.method ~= "GET" then
    error("http tester: only GET, PUT and POST methods supported")
  end

  req.headers = { TIMEOUT = 10 }
  if item.headers then
    for key, value in pairs(item.headers) do req.headers[key] = value end
  end

  req.sink = function (chunk, err)
    if chunk then sinkdata[#sinkdata + 1] = chunk end
    return true
  end

  local r, s = httpqs(item.url).request(req)

  if not r then
    report.short = table.concat{ "connect to ", item.url, " failed" }
    return report
  end
  if item.check_status and not item.check_status == s then
    report.short = table.concat{ "unexpected status from ", item.url }
    return report
  end
  if item.match_response and not check_content(item, table.concat(sinkdata)) then
    report.short = table.concat{ "unexpected response from ", item.url }
    return report
  end

  report.online = true
  report.short = table.concat{ item.url, " is back to normal" }
  return report
end

local reports = {}
local test_id_dups = {}

for _, test in ipairs(conf.monitor) do
  if not tests[test.type] then
    error("invalid test type: " .. test.type)
  end

  local now = os.time()
  local report = tests[test.type](test)
  if test_id_dups[report.test_id] then
    error("duplicate test id: " .. report.test_id)
  end
  test_id_dups[report.test_id] = true
  report.time = now

  local state = states[report.test_id] or { online = true, reports = {} }
  if not states[report.test_id] then states[report.test_id] = state end
  state.last_attempt = now

  if not report.online then
    if state.online or os.difftime(now, state.last_report) >= (conf.remind_period or 28000) then
      state.online = false
      table.insert(state.reports, report)
      table.insert(reports, report)
      state.last_report = now
    end
  else
    if not state.online then
      state.online = true
      table.insert(state.reports, report)
      table.insert(reports, report)
    end
  end
end

local states_file = io.open(states_filename, "w")
states_file:write(require"serpent".dump(states))
states_file:close()

local reporters = {}

local function form_encode(t)
  local r = {}
  for key, value in pairs(t) do
    if #r > 0 then r[#r + 1] = "&" end
    r[#r + 1] = socket.url.escape(key)
    r[#r + 1] = "="
    r[#r + 1] = socket.url.escape(value)
  end
  return table.concat(r)
end

function reporters.http(item, text)
  assert(item.method == "GET" or item.method == "POST", "http reporter, only GET and POST method implemented")
  assert(item.report_mode == "short", "http reporter, only short report_mode implemented")
  assert(item.method == "GET" or item.encoding == "form" or item.encoding == "json", "http reporter, only form or json are supported encodings for POST method")

  local req = {
    method = item.method,
    headers = {},
  }
  local params = {}
  for key, value in pairs(item.other_params) do params[key] = value end
  params[item.report_param] = (item.report_prefix or "") .. text

  if item.method == "GET" then
    req.url = table.concat{ item.url, "?", form_encode(params) }
  else
    req.url = item.url:gsub(":(%w+)", function (_, k) return socket.url.escape(params[k]) end)
    local source_data
    if item.encoding == "json" then
      source_data = require"cjson".encode(params)
      req.headers["Content-Type"] = "application/json"
    else
      source_data = form_encode(params)
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    end
    req.source = coroutine.wrap(function ()
      coroutine.yield(source_data)
    end)
  end
  httpqs(req.url).request(req)
end

function reporters.console(item, text)
  print(text)
end

for _, r in ipairs(reports) do
  for _, rpt in ipairs(conf.report) do
    if reporters[rpt.type] then reporters[rpt.type](rpt, r.short) end
  end
end

