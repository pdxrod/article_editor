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
    post "/", PageController, :index
    get "/", PageController, :index
    post "/edit/:id", PageController, :edit
    get "/edit/:id", PageController, :edit
    get "/find/:s/:c", PageController, :find
  end
end
