defmodule DdbmsServerWeb.Router do
  use DdbmsServerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DdbmsServerWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/api", DdbmsServerWeb do
    pipe_through :api

    post "/setup", PageController, :setup
    post "/reset", PageController, :reset
  end
end
