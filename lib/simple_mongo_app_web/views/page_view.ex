defmodule SimpleMongoAppWeb.PageView do
  use SimpleMongoAppWeb, :view

  @new_column_reg ~r/<label.+new column.+input.+new_column.+/
  @new_column_field "<label style='width: 49%; float: left' for='new_column'>new column?</label> <input style='width: 49%; float: left;' id='new_column' name='new_column' type='text' value=''>\n<br/> "
  @dele_button_field "<span><button class='btn btn-default btn-xs' id='dele_button_ID' name='dele_button_ID' type='submit' style='background-color: #ff99cc; width: 80px;'>Delete</button></span>\n"
  @save_button_field "<span><button class='btn btn-default btn-xs' id='save_button_ID' name='save_button_ID' type='submit' style='background-color: #00ffff; width: 80px;'>Save</button></span>\n"
  @edit_button_field "<span><button class='btn btn-default btn-xs' id='edit_button_ID' name='edit_button_ID' onclick=\"reg_check_ID(); return false;\" style='background-color: #66ffcc; width: 80px;'>Edit</button></span>"
  @reg_javascript_fn """
  <script>
      function reg_check_ID() {
        window.location = "/edit/ID";
        return false;
      }
  // Thx https://stackoverflow.com/questions/27725127/redirect-using-window-location-doesnt-work
  </script>
  """

  @types ~w[function nil integer binary bitstring list map float atom tuple pid port reference]
  for type <- @types do
    defp typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
  end

  defp stringify_key_val( key, val ) do
    if val == nil do
      ""
    else
      if typeof( val ) == "binary" do
        if key == "_id" do
          val                # It's a hex string
        else
          "<span><label style='width: 49%; float: left' for='#{key}'>#{key}</label> <input style='width: 49%; float: left;' id='#{key}' name='#{key}' type='text' value='#{val}'></span><br/>\n"
        end
      else
        str = Base.encode16(val.value, case: :lower)
        "#{ str }" # It's a %BSON.ObjectId{value: "HEXNUM"}
      end
    end
  end

  defp stringify_keys( keys, map ) do
    case keys do
      [] -> ""
      [hd | tl] ->
        key = List.first( keys )
        stringify_key_val( key, map[ key ]) <> stringify_keys( tl, map )
    end
  end

  defp stringify_map( map ) do
    keys = Map.keys( map )
    keys = List.delete( keys, "page" )
    str = stringify_keys( keys, map )
    id = String.slice str, 0..23
    str = String.slice str, 24..-1
    str = if str =~ @new_column_reg do
      str
    else
      str <> @new_column_field
    end
    del = String.replace @dele_button_field, "ID", id
    save = String.replace @save_button_field, "ID", id
    javascript = String.replace @reg_javascript_fn, "ID", id
    edit = String.replace @edit_button_field, "ID", id
    str = str <> save <> javascript <> edit <> "&nbsp;" <> del
    [ { id, str } ] # id is the first 24 characters of the string returned by stringify_keys - str is the rest of i
  end

  defp stringify_list( list ) do
    case list do
      [] -> []
      [hd | tl] -> stringify_map( hd ) ++ stringify_list( tl )
    end
  end

  defp empty_row do
    id = String.slice( RandomBytes.base16, 0..23 )
    map = %{ name: "", classification: "" }
    str = stringify_keys( Map.keys( map ), map )
    save = String.replace @save_button_field, "ID", id
    label = "<div><b>New article</b></div>\n<br/>"
    [ { id, label <> str <> save } ]
  end

  defp articles do
    cursor = Mongo.find(:article, "my_app_db", %{})
    list = cursor |> Enum.to_list() |> stringify_list
    list ++ empty_row()
  end

# ------------------------------------------------------------------------------
# private ^ public v

  def show_articles do
    try do
      articles()
    rescue
      re in RuntimeError -> re
      [ { "decaf0ff", "Error: #{ re.message }" } ]
    end
  end

  def show_article( id ) do
    cursor = Mongo.find(:article, "my_app_db", %{"_id" => id})
    list = cursor |> Enum.to_list()
    article = List.first( list )
    class = article[ "classification" ]
    name = article[ "name" ]
    page = article[ "page" ]
    { class, name, page }
  end

end
