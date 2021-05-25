defmodule SimpleMongoAppWeb.ReadController do
  use SimpleMongoAppWeb, :controller
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.MemoryDb

  defp analyse_params( params ) do
    id = params[ "id" ]
    if id == nil do
      Utils.debug "Just displaying the edit page, not hitting the button"
    else
      Utils.debug "Just displaying the editor, not hitting any buttons"
    end
    id
  end

# ------------------------------------------------------------------------------
# private ^ public v

    def edit( conn, params ) do
      Utils.debug "edit()"
      args = HtmlUtils.trim_vals params
      id = analyse_params args
      if MemoryDb.valid_id? id do
        conn = assign(conn, :id, id)
        conn = render conn, "edit.html"
        Utils.debug "edit params id #{ id }"
        conn
      else
        assign(conn, :error, "Invalid value '#{ id }'")
        conn |> Phoenix.Controller.redirect(to: "/")
      end
    end

    def index(conn, params) do
      args = HtmlUtils.trim_vals params
      Utils.debug "index()"
      conn =
        if args[ "c" ] do
          class = args["c"]
          page_num = args["p"]
          assign(conn, :c, class)
          assign(conn, :p, page_num)
        else
          page_num = args["p"]
          assign(conn, :p, page_num)
          Utils.debug "Just looking at the index page with page_num #{page_num}", 3
          conn
        end
      render conn, "index.html"
    end

    def find( conn, params ) do
      HtmlUtils.find conn, params
    end

end
