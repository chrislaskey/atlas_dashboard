defmodule ArtemisWeb.ViewHelper.Events do
  use Phoenix.HTML

  import ArtemisWeb.Guardian.Helpers

  @doc """
  Render event log notifier
  """
  def render_event_log_notifications(conn, type, id \\ nil) do
    user = current_user(conn)

    Phoenix.LiveView.live_render(
      conn,
      ArtemisWeb.EventLogNotificationsLive,
      session: %{
        current_user: user,
        resource_id: id,
        resource_type: type
      }
    )
  end

  @doc """
  Render event log list
  """
  def render_event_log_list(conn, event_logs, options \\ []) do
    assigns = [
      allowed_columns: Keyword.get(options, :allowed_columns),
      conn: conn,
      default_columns: Keyword.get(options, :default_columns, []),
      event_logs: event_logs,
      pagination_options: Keyword.get(options, :pagination_options, [])
    ]

    Phoenix.View.render(ArtemisWeb.EventLogView, "_list.html", assigns)
  end
end
