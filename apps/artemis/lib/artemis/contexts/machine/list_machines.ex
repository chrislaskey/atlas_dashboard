defmodule Artemis.ListMachines do
  use Artemis.Context

  use Artemis.ContextCache,
    cache_reset_on_events: [
      "machine:created",
      "machine:deleted",
      "machine:updated"
    ]

  import Artemis.Helpers.Filter
  import Artemis.Helpers.Search
  import Ecto.Query

  alias Artemis.Machine
  alias Artemis.Repo

  @default_order "name"
  @default_page_size 25
  @default_preload []

  def call(params \\ %{}, user) do
    params = default_params(params)

    Machine
    |> distinct_query(params, default: true)
    |> preload(^Map.get(params, "preload"))
    |> filter_query(params, user)
    |> search_filter(params)
    |> order_query(params)
    |> select_count(params)
    |> get_records(params)
  end

  defp default_params(params) do
    params
    |> Artemis.Helpers.keys_to_strings()
    |> Map.put_new("order", @default_order)
    |> Map.put_new("page_size", @default_page_size)
    |> Map.put_new("preload", @default_preload)
  end

  defp filter_query(query, %{"filters" => filters}, _user) when is_map(filters) do
    Enum.reduce(filters, query, fn {key, value}, acc ->
      filter(acc, key, value)
    end)
  end

  defp filter_query(query, _params, _user), do: query

  defp filter(query, "cloud_id", value), do: where(query, [i], i.cloud_id in ^split(value))
  defp filter(query, "data_center_id", value), do: where(query, [i], i.data_center_id in ^split(value))
  defp filter(query, "hostname", value), do: where(query, [i], i.hostname in ^split(value))
  defp filter(query, "name", value), do: where(query, [i], i.name in ^split(value))
  defp filter(query, "slug", value), do: where(query, [i], i.slug in ^split(value))

  defp get_records(query, %{"paginate" => true} = params), do: Repo.paginate(query, pagination_params(params))
  defp get_records(query, _params), do: Repo.all(query)
end
