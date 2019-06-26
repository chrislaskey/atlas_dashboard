defmodule Artemis.DeleteSharedJob do
  use Artemis.Context

  alias Artemis.Drivers.IBMCloudant
  alias Artemis.GetSharedJob
  alias Artemis.SharedJob

  def call!(id, user) do
    case call(id, user) do
      {:error, _} -> raise(Artemis.Context.Error, "Error deleting shared job")
      {:ok, result} -> result
    end
  end

  def call(id, user) do
    id
    |> get_record(user)
    |> delete_record()
    |> parse_response()
    |> Event.broadcast("shared-jobs:deleted", user)
  end

  def get_record(%{id: id}, user), do: get_record(id, user)
  def get_record(id, user), do: GetSharedJob.call(id, user)

  defp delete_record(%{_id: id, _rev: rev}) do
    cloudant_host = SharedJob.get_cloudant_host()
    cloudant_path = SharedJob.get_cloudant_path()
    query_params = [rev: rev]

    IBMCloudant.Request.call(%{
      host: cloudant_host,
      method: :delete,
      params: query_params,
      path: "#{cloudant_path}/#{id}"
    })
  end

  defp parse_response({:ok, body}), do: body
  defp parse_response(_), do: {:error, "Error deleting shared job"}
end
