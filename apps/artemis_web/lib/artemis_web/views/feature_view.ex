defmodule ArtemisWeb.FeatureView do
  use ArtemisWeb, :view

  # Data Table

  def data_table_available_columns() do
    [
      {"Actions", "actions"},
      {"Active", "active"},
      {"Name", "name"},
      {"Slug", "slug"}
    ]
  end

  def data_table_allowed_columns() do
    %{
      "actions" => [
        label: fn _conn -> nil end,
        value: fn _conn, _row -> nil end,
        value_html: &data_table_actions_column_html/2
      ],
      "active" => [
        label: fn _conn -> "Status" end,
        label_html: fn conn ->
          sortable_table_header(conn, "active", "Status")
        end,
        value: fn _conn, row ->
          case row.active do
            true -> "Active"
            false -> "Inactive"
          end
        end
      ],
      "name" => [
        label: fn _conn -> "Name" end,
        label_html: fn conn ->
          sortable_table_header(conn, "name", "Name")
        end,
        value: fn _conn, row -> row.name end,
        value_html: fn conn, row ->
          case has?(conn, "features:show") do
            true -> link(row.name, to: Routes.feature_path(conn, :show, row))
            false -> row.name
          end
        end
      ],
      "slug" => [
        label: fn _conn -> "Slug" end,
        label_html: fn conn ->
          sortable_table_header(conn, "slug", "Slug")
        end,
        value: fn _conn, row -> row.slug end,
        value_html: fn _conn, row ->
          content_tag(:code, row.slug)
        end
      ]
    }
  end

  defp data_table_actions_column_html(conn, row) do
    allowed_actions = [
      [
        verify: has?(conn, "features:show"),
        link: link("Show", to: Routes.feature_path(conn, :show, row))
      ],
      [
        verify: has?(conn, "features:update"),
        link: link("Edit", to: Routes.feature_path(conn, :edit, row))
      ],
      [
        verify: has?(conn, "features:delete"),
        link:
          link("Delete",
            to: Routes.feature_path(conn, :delete, row),
            method: :delete,
            data: [confirm: "Are you sure?"]
          )
      ]
    ]

    Enum.reduce(allowed_actions, [], fn action, acc ->
      case Keyword.get(action, :verify) do
        true -> [acc | Keyword.get(action, :link)]
        _ -> acc
      end
    end)
  end
end
