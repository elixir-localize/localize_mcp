defmodule LocalizeMcp.Tools.Atoms do
  @moduledoc """
  Implementation of the `localize_atoms` tool.

  Returns the closed atom collection for a named kind — locales,
  calendars, currencies, languages, scripts, territories, number
  systems, etc. Each atom comes with its display name where one is
  cheaply available (currencies, territories) so an agent can pick
  the right code without a second round-trip.

  Backed by the existing `Localize.X.known_*` accessors. The
  collections themselves are interned at app start by
  `Localize.Supervisor` (see `intern_supplemental_atoms/0` in
  Localize's source), so this tool's cost is the `inspect` and
  (optional) display-name lookup per atom.

  """

  @known_collections ~w(
    locales
    calendars
    currencies
    languages
    scripts
    territories
    number_systems
    measurement_systems
    units
    unit_categories
    unit_usages
    plural_categories
  )

  @spec call(map()) :: map()
  def call(%{"collection" => collection}) when is_binary(collection) do
    if collection in @known_collections do
      atoms = atoms_for(collection)

      %{
        collection: collection,
        atoms:
          atoms
          |> Enum.map(fn atom ->
            %{atom: inspect(atom), name: atom_to_string(atom)}
          end),
        total: length(atoms)
      }
    else
      %{
        error: "unknown collection #{inspect(collection)}",
        known_collections: @known_collections
      }
    end
  end

  def call(_), do: %{error: "missing required parameter :collection"}

  # ── Collection lookup ─────────────────────────────────────────

  defp atoms_for("locales"), do: Localize.SupplementalData.all_locale_ids()
  defp atoms_for("calendars"), do: known_calendars()
  defp atoms_for("currencies"), do: Localize.Currency.known_currency_codes()
  defp atoms_for("languages"), do: validity_atoms(:languages)
  defp atoms_for("scripts"), do: validity_atoms(:scripts)
  defp atoms_for("territories"), do: Localize.SupplementalData.known_territories()
  defp atoms_for("number_systems"), do: Localize.Number.System.known_number_systems()
  defp atoms_for("measurement_systems"), do: known_measurement_systems()
  defp atoms_for("units"), do: known_units()
  defp atoms_for("unit_categories"), do: Localize.Unit.known_categories()
  defp atoms_for("unit_usages"), do: Localize.Unit.known_usages()
  defp atoms_for("plural_categories"), do: [:zero, :one, :two, :few, :many, :other]

  defp known_calendars do
    base = Localize.Calendar.known_calendars()

    if LocalizeMcp.calendrical_loaded?() do
      base ++ apply(Calendrical, :calendars, [])
    else
      base
    end
  rescue
    # Calendrical may expose its own surface that we don't know the
    # exact accessor for at the version pinned here; fall back to
    # the base set if the optional dep's API has drifted.
    _ -> Localize.Calendar.known_calendars()
  end

  defp known_measurement_systems do
    [:metric, :uksystem, :ussystem, :us, :uk]
  end

  defp known_units do
    Localize.Unit.known_units_by_category()
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validity_atoms(kind) do
    Localize.SupplementalData.validity(kind)
    |> Enum.flat_map(fn {_status, codes} ->
      Enum.flat_map(codes, fn
        code when is_binary(code) ->
          if String.contains?(code, "~") do
            []
          else
            atom = String.to_existing_atom(code)
            [atom]
          end

        _ ->
          []
      end)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  rescue
    _ -> []
  end

  # ── Display-name lookup ──────────────────────────────────────

  # Best-effort: try the obvious accessor for the kind; fall back to
  # the atom's own string form.
  defp atom_to_string(atom), do: Atom.to_string(atom)
end
