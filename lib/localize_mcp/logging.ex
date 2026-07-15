defmodule LocalizeMcp.Logging do
  @moduledoc false

  # The MCP stdio transport owns standard output: hosts parse every
  # stdout line as a JSON-RPC frame, so a single log line on stdout
  # corrupts the session. The `mix localize_mcp` entry point calls
  # this BEFORE the applications start, so boot-time log output from
  # dependencies also lands on stderr.

  @spec redirect_to_stderr() :: :ok
  def redirect_to_stderr do
    # Any later restart of the :logger application (Mix's app.start
    # does one to apply project config) must come back on stderr.
    Application.put_env(:logger, :default_handler, config: [type: :standard_error])

    # And move the currently-installed handler. A live logger_std_h
    # refuses a device change (:illegal_config_change), so the
    # default handler is removed and re-added.
    case :logger.get_handler_config(:default) do
      {:ok, %{module: module} = handler_config} ->
        device_config =
          handler_config
          |> Map.get(:config, %{})
          |> Map.put(:type, :standard_error)

        :ok = :logger.remove_handler(:default)
        :ok = :logger.add_handler(:default, module, %{handler_config | config: device_config})

      {:error, _not_found} ->
        :ok
    end

    :ok
  end
end
