import Config

# Tests exercise tool handlers directly; they do not need a live
# MCP server attached to stdio. Skip the server child so ExUnit
# output stays clean and `mix test` doesn't leave a process
# competing for the terminal's stdin.
config :localize_mcp, start_server: false

# Quieten Hermes-MCP / Logger noise during the test run. Tools
# that need to assert on log output should call
# `Logger.configure(level: :info)` themselves.
config :logger, level: :warning
