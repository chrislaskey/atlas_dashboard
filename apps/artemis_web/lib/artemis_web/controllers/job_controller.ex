defmodule ArtemisWeb.JobController do
  use ArtemisWeb, :controller

  use ArtemisWeb.Controller.BulkActions,
    bulk_actions: ArtemisWeb.JobView.available_bulk_actions(),
    path: &Routes.job_path(&1, :index),
    permission: "jobs:list"

  use ArtemisWeb.Controller.CommentsShow,
    path: &Routes.job_path/3,
    permission: "jobs:show",
    resource_getter: &Artemis.GetJob.call!/2,
    resource_id_key: "job_id",
    resource_type: "Job"

  use ArtemisWeb.Controller.EventLogsIndex,
    path: &Routes.job_path/3,
    permission: "jobs:list",
    resource_type: "Job"

  use ArtemisWeb.Controller.EventLogsShow,
    path: &Routes.job_event_log_path/4,
    permission: "jobs:show",
    resource_getter: &Artemis.GetJob.call!/2,
    resource_id: "job_id",
    resource_type: "Job",
    resource_variable: :job

  alias Artemis.CreateJob
  alias Artemis.DeleteJob
  alias Artemis.GetJob
  alias Artemis.Job
  alias Artemis.ListJobs
  alias Artemis.UpdateJob

  def index(conn, params) do
    authorize(conn, "jobs:list", fn ->
      user = current_user(conn)
      params = Map.put(params, :paginate, true)
      jobs = ListJobs.call(params, user)
      search_enabled = Job.search_enabled?()
      allowed_bulk_actions = ArtemisWeb.JobView.allowed_bulk_actions(user)

      assigns = [
        allowed_bulk_actions: allowed_bulk_actions,
        jobs: jobs,
        search_enabled: search_enabled
      ]

      render_format(conn, "index", assigns)
    end)
  end

  def new(conn, _params) do
    authorize(conn, "jobs:create", fn ->
      job = %Job{raw_data: %{}}
      changeset = Job.changeset(job)

      render(conn, "new.html", changeset: changeset, job: job)
    end)
  end

  def create(conn, %{"job" => params}) do
    authorize(conn, "jobs:create", fn ->
      case CreateJob.call(params, current_user(conn)) do
        {:ok, job} ->
          conn
          |> put_flash(:info, "Job created successfully.")
          |> redirect(to: Routes.job_path(conn, :show, job._id))

        {:error, %Ecto.Changeset{} = changeset} ->
          job = %Job{raw_data: %{}}

          render(conn, "new.html", changeset: changeset, job: job)
      end
    end)
  end

  def show(conn, %{"id" => id}) do
    authorize(conn, "jobs:show", fn ->
      user = current_user(conn)
      job = GetJob.call!(id, user)

      render(conn, "show.html", job: job)
    end)
  rescue
    _ in Artemis.Context.Error -> render_not_found(conn)
  end

  def edit(conn, %{"id" => id}) do
    authorize(conn, "jobs:update", fn ->
      job = GetJob.call!(id, current_user(conn))
      changeset = Job.changeset(job)

      render(conn, "edit.html", changeset: changeset, job: job)
    end)
  end

  def update(conn, %{"id" => id, "job" => params}) do
    authorize(conn, "jobs:update", fn ->
      case UpdateJob.call(id, params, current_user(conn)) do
        {:ok, job} ->
          conn
          |> put_flash(:info, "Job updated successfully.")
          |> redirect(to: Routes.job_path(conn, :show, job._id))

        {:error, %Ecto.Changeset{} = changeset} ->
          job = GetJob.call(id, current_user(conn))

          render(conn, "edit.html", changeset: changeset, job: job)
      end
    end)
  end

  def delete(conn, %{"id" => id} = params) do
    authorize(conn, "jobs:delete", fn ->
      {:ok, _job} = DeleteJob.call(id, params, current_user(conn))

      conn
      |> put_flash(:info, "Job deleted successfully.")
      |> redirect(to: Routes.job_path(conn, :index))
    end)
  end
end
