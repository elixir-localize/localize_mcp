defmodule LocalizeMcp.Tools.Invoke do
  @moduledoc """
  Implementation of the `localize_invoke` tool.

  Executes one allowlisted MFA from `priv/mcp/invocable.exs` and
  returns its result encoded through `LocalizeMcp.TermGrammar`.

  Three safety layers:

    1. **Allowlist**. The MFA must appear in
       `priv/mcp/invocable.exs`; everything else returns
       `:not_invokable`.

    2. **Task isolation**. The call runs in a `Task.async/1` so the
       caller's process dictionary (current locale, etc.) stays
       clean and exceptions / exits are captured locally.

    3. **Resource caps**. 5 second wall-clock timeout. The
       `:max_heap_size` flag is applied to the task process so a
       runaway call cannot grow the BEAM unboundedly.

  Exceptions and timeouts return as structured `{:error, ...}`
  maps; the tool never raises.

  """

  alias LocalizeMcp.TermGrammar

  @timeout_ms 5_000
  @max_heap_words 8 * 1024 * 1024

  @persistent_term_key {:localize_mcp, :invocable}

  @spec call(map()) :: map()
  def call(%{"mfa" => mfa_str, "args" => args}) when is_binary(mfa_str) and is_list(args) do
    with {:ok, {module, function, arity}} <- parse_mfa(mfa_str),
         :ok <- check_allowlist(module, function, arity),
         :ok <- check_arity(args, arity),
         {:ok, decoded_args} <- decode_args(args) do
      execute(module, function, decoded_args)
    else
      # All non-success branches return an error *map* (not a
      # tuple), so call/1's caller sees a consistent shape.
      %{} = error_map -> error_map
      {:error, error_map} when is_map(error_map) -> error_map
    end
  end

  def call(_), do: %{error: "required parameters: :mfa (string), :args (list)"}

  # ── Allowlist (built once, cached in :persistent_term) ───────

  @doc false
  @spec allowlist() :: [{module(), atom(), arity()}]
  def allowlist do
    case :persistent_term.get(@persistent_term_key, :not_loaded) do
      :not_loaded ->
        list = load_allowlist()
        :persistent_term.put(@persistent_term_key, list)
        list

      list ->
        list
    end
  end

  defp load_allowlist do
    path = Application.app_dir(:localize_mcp, ["priv", "mcp", "invocable.exs"])
    {list, _} = Code.eval_file(path)
    list
  rescue
    _ -> []
  end

  defp check_allowlist(module, function, arity) do
    if {module, function, arity} in allowlist() do
      :ok
    else
      %{
        error: "not_invokable",
        mfa: "#{inspect(module)}.#{function}/#{arity}",
        note:
          "MFA is not in the allowlist. See priv/mcp/invocable.exs in the localize_mcp repo. " <>
            "If this is a legitimate omission, file an issue or PR."
      }
    end
  end

  # ── MFA parsing ──────────────────────────────────────────────

  defp parse_mfa(mfa_str) do
    case Regex.run(~r/^([A-Za-z0-9_.]+)\.([a-z_!?]+[a-zA-Z0-9_!?]*)\/(\d+)$/, mfa_str) do
      [_, module_str, function_str, arity_str] ->
        try do
          module = String.to_existing_atom("Elixir." <> module_str)
          function = String.to_existing_atom(function_str)
          arity = String.to_integer(arity_str)
          {:ok, {module, function, arity}}
        rescue
          _ -> {:error, %{error: "unknown MFA #{inspect(mfa_str)}"}}
        end

      _ ->
        {:error, %{error: "malformed MFA #{inspect(mfa_str)} (expected \"Module.fun/arity\")"}}
    end
  end

  defp check_arity(args, arity) do
    if length(args) == arity do
      :ok
    else
      %{
        error: "arity_mismatch",
        expected: arity,
        got: length(args)
      }
    end
  end

  # ── Argument decoding ────────────────────────────────────────

  defp decode_args(args) do
    decoded =
      Enum.reduce_while(args, [], fn arg, acc ->
        case TermGrammar.decode(arg) do
          {:ok, term} -> {:cont, [term | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case decoded do
      {:error, reason} ->
        %{error: "argument_decode_failed", detail: inspect(reason)}

      list ->
        {:ok, Enum.reverse(list)}
    end
  end

  # ── Execution ────────────────────────────────────────────────

  defp execute(module, function, args) do
    task =
      Task.async(fn ->
        try do
          Process.flag(:max_heap_size, %{
            size: @max_heap_words,
            kill: true,
            error_logger: false
          })

          {:ok, apply(module, function, args)}
        rescue
          exception -> {:raised, exception, __STACKTRACE__}
        catch
          kind, reason -> {:caught, kind, reason, __STACKTRACE__}
        end
      end)

    case Task.yield(task, @timeout_ms) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        %{ok: true, result: TermGrammar.encode(result)}

      {:ok, {:raised, exception, _stacktrace}} ->
        %{
          ok: false,
          error: %{
            kind: "exception",
            module: inspect(exception.__struct__),
            message: Exception.message(exception)
          }
        }

      {:ok, {:caught, kind, reason, _stacktrace}} ->
        %{
          ok: false,
          error: %{
            kind: Atom.to_string(kind),
            reason: inspect(reason)
          }
        }

      nil ->
        %{
          ok: false,
          error: %{
            kind: "timeout",
            message: "call exceeded #{@timeout_ms} ms timeout and was killed"
          }
        }

      {:exit, reason} ->
        # Heap-cap kills surface as {:exit, :killed} via Task.shutdown.
        %{
          ok: false,
          error: %{kind: "exit", reason: inspect(reason)}
        }
    end
  end
end
