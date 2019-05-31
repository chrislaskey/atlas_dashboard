defmodule Artemis.IntervalWorker do
  @moduledoc """
  A `use` able module for creating GenServer instances that perform tasks on a
  set interval.

  ## Callbacks

  Define a `call/1` function to be executed at the interval. Receives the
  current `state.data`.

  Must return a tuple `{:ok, _}` or `{:error, _}`.

  ## Options

  Takes the following options:

    :name - Required. Name of the server.
    :enabled - Optional. If set to false, starts in paused state.
    :interval - Optional. Interval between calls.
    :log_limit - Optional. Number of log entries to keep.

  For example:

    use Artemis.IntervalWorker,
      interval: 15_000,
      log_limit: 500,
      name: :repo_reset_on_interval

  """

  @callback call(map()) :: {:ok, any()} | {:error, any()}

  defmacro __using__(options) do
    quote do
      require Logger

      use GenServer

      defmodule State do
        defstruct [
          :data,
          :timer,
          log: []
        ]
      end

      defmodule Data do
        defstruct [
          :meta,
          :result
        ]
      end

      defmodule Log do
        defstruct [
          :details,
          :duration,
          :ended_at,
          :started_at,
          :success
        ]
      end

      @behaviour Artemis.IntervalWorker
      @default_interval 60_000
      @default_log_limit 500

      def start_link() do
        initial_state = %State{
          data: %Data{}
        }

        options = [
          name: get_name()
        ]

        GenServer.start_link(__MODULE__, initial_state, options)
      end

      def get_name(), do: get_option(:name)

      def get_data(), do: GenServer.call(get_name(), :data)

      def get_log(), do: GenServer.call(get_name(), :log)

      def get_options(), do: unquote(options)

      def get_option(key, default \\ nil), do: Keyword.get(get_options(), key, default)

      def get_result(), do: GenServer.call(get_name(), :result)

      def get_state(), do: GenServer.call(get_name(), :state)

      def pause(), do: GenServer.call(get_name(), :pause)

      def resume(), do: GenServer.call(get_name(), :resume)

      def update(), do: Process.send(get_name(), :update, [])

      # Callbacks

      @impl true
      def init(state) do
        state =
          case get_option(:enabled, true) do
            true -> Map.put(state, :timer, schedule_update())
            false -> state
          end

        {:ok, state}
      end

      @impl true
      def handle_call(:data, _from, state) do
        {:reply, state.data, state}
      end

      @impl true
      def handle_call(:log, _from, state) do
        {:reply, state.log, state}
      end

      @impl true
      def handle_call(:pause, _from, state) do
        if state.timer do
          Process.cancel_timer(state.timer)
        end

        {:reply, true, %State{state | timer: nil}}
      end

      @impl true
      def handle_call(:result, _from, state) do
        result = Artemis.Helpers.deep_get(state, [:data, :result])

        {:reply, result, state}
      end

      @impl true
      def handle_call(:resume, _from, state) do
        if state.timer do
          Process.cancel_timer(state.timer)
        end

        {:reply, true, %State{state | timer: schedule_update()}}
      end

      @impl true
      def handle_call(:state, _from, state) do
        {:reply, state, state}
      end

      @impl true
      def handle_info(:update, state) do
        started_at = Timex.now()
        result = call(state.data)
        ended_at = Timex.now()

        state =
          state
          |> Map.put(:data, parse_data(state, result))
          |> Map.put(:log, update_log(state, result, started_at, ended_at))
          |> Map.put(:timer, schedule_update_unless_paused(state))

        {:noreply, state}
      end

      def handle_info(_, state) do
        {:noreply, state}
      end

      # Callback Helpers

      defp schedule_update() do
        interval = get_option(:interval, @default_interval)

        Process.send_after(self(), :update, interval)
      end

      defp schedule_update_unless_paused(%{timer: timer}) when is_nil(timer), do: nil
      defp schedule_update_unless_paused(%{timer: timer}) do
        Process.cancel_timer(timer)

        schedule_update()
      end

      def parse_data(_state, {:ok, data}), do: data
      def parse_data(%{data: current_data}, _), do: current_data

      defp update_log(%{log: log}, result, started_at, ended_at) do
        entry = %Log{
          details: elem(result, 1),
          duration: Timex.diff(ended_at, started_at),
          ended_at: ended_at,
          started_at: started_at,
          success: success?(result)
        }

        log_limit = get_option(:log_limit, @default_log_limit)
        truncated = Enum.slice(log, 0, log_limit)

        [entry | truncated]
      end

      defp success?({:ok, _}), do: true
      defp success?(_), do: false

      # Allow defined `@callback`s to be overwritten

      defoverridable Artemis.IntervalWorker
    end
  end
end