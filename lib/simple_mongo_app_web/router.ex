defmodule SimpleMongoAppWeb.Router do
  use SimpleMongoAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", SimpleMongoAppWeb do
    pipe_through :browser
    post "/", ReadController, :index
    get "/", ReadController, :index
    post "/read/edit/:id", ReadController, :edit
    get "/read/edit/:id", ReadController, :edit
    get "/read/find/:s/:c/:p", ReadController, :find
    post "/write", WriteController, :index
    get "/write", WriteController, :index
    post "/write/edit/:id", WriteController, :edit
    get "/write/edit/:id", WriteController, :edit
    get "/write/find/:s/:c/:p", WriteController, :find
    post "/write/login", WriteController, :login
    get "/write/login", WriteController, :login
  end

  pipeline :basic_auth do
    plug :my_basic_auth
  end

  defp my_basic_auth(conn, _opts) do
    {user, pass} = Plug.BasicAuth.parse_basic_auth(conn)

    case SimpleMongoAppWeb.API.Authentication.authenticate(conn, user, pass) do
      {:ok, conn} ->
        conn

      {:error, conn} ->
        conn |> SimpleMongoAppWeb.API.Helpers.unauthorized_response()
    end
  end


end
