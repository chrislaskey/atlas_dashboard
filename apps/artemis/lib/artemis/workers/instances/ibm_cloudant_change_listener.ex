defmodule Artemis.Worker.IBMCloudantChangeListener do
  use Artemis.IntervalWorker,
    enabled: enabled?(),
    interval: get_request_timeout() - 5_000,
    log_limit: 500,
    name: :ibm_cloudant_change_listener

  alias Artemis.Drivers.IBMCloudant

  defmodule Data do
    defstruct [
      :connection,
      :database,
      :host,
      :last_sequence
    ]
  end

  @hackney_pool :cloudant_change_watcher_pool

  # Callbacks

  @impl true
  def call(data) do
    data = get_data_struct(data)

    host = Artemis.SharedJob.cloudant_host()
    database = Artemis.SharedJob.cloudant_database()
    timeout = get_request_timeout()

    ensure_connection_pool_available()

    query_params = [
      feed: "continuous",
      include_docs: true,
      since: data.last_sequence || "now",
      style: "main_only",
      timeout: timeout
    ]

    options = [
      async: :once,
      hackney: [pool: @hackney_pool],
      recv_timeout: timeout,
      stream_to: self(),
      timeout: timeout
    ]

    if Artemis.Helpers.present?(data.connection) do
      :hackney.stop_async(data.connection)
    end

    {:ok, connection} = IBMCloudant.call(%{
      method: :get,
      options: options,
      params: query_params,
      url: "#{host}/#{database}/_changes"
    })

    {:ok, struct(data, connection: connection, database: database, host: host)}
  end

  @impl true
  def handle_info_callback(%HTTPoison.AsyncChunk{chunk: chunk}, state) when chunk == "\n" do
    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    decoded = decode_data(chunk)
    sequence = Map.get(decoded, "seq")
    state = store_last_sequence(state, sequence)

    broadcast_cloudant_change(decoded, state.data.database, state.data.host)

    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncEnd{}, state) do
    update(async: true)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncHeaders{}, state) do
    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncRedirect{}, state) do
    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncResponse{}, state) do
    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(%HTTPoison.AsyncStatus{}, state) do
    HTTPoison.stream_next(state.data.connection)

    {:noreply, state}
  end

  def handle_info_callback(_, state) do
    {:noreply, state}
  end

  # Helpers

  defp enabled? do
    :artemis
    |> Application.fetch_env!(:actions)
    |> Keyword.fetch!(:ibm_cloudant_change_listener)
    |> Keyword.fetch!(:enabled)
  end

  defp get_request_timeout do
    # IBM Cloudant API times out after 60 seconds
    60_000
  end

  defp ensure_connection_pool_available do
    case :hackney_pool.find_pool(@hackney_pool) do
      :undefined -> start_connection_pool()
      _ -> :ok
    end
  end

  defp start_connection_pool do
    options = [
      timeout: get_request_timeout(),
      max_connections: 10
    ]

    :ok = :hackney_pool.start_pool(@hackney_pool, options)
  end

  defp get_data_struct(%Data{} = value), do: value
  defp get_data_struct(map) when is_map(map), do: struct(Data, map)
  defp get_data_struct(_), do: %Data{}

  defp decode_data(data) do
    Jason.decode!(data)
  rescue
    _ -> nil
  end

  defp store_last_sequence(state, value) do
    data = struct(state.data, last_sequence: value)

    Map.put(state, :data, data)
  end

  defp broadcast_cloudant_change(data, database, host) do
    document = Map.get(data, "doc")
    id = Map.get(data, "id")

    action =
      case Map.get(data, "deleted") do
        nil -> "change"
        _ -> "delete"
      end

    Artemis.CloudantChange.broadcast(%{
      action: action,
      database: database,
      document: document,
      host: host,
      id: id
    })
  end
end