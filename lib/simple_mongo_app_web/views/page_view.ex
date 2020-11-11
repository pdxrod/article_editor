defmodule SimpleMongoAppWeb.PageView do
  use SimpleMongoAppWeb, :view

  defp start_mongo do
    Mongo.start_link(
      name: :article,
      database: "my_app_db",
      hostname: "localhost",
      username: "root",
      password: "rootpassword"
    )
  end

  @new_column_field "new column <input id='new_column' name='new_column' type='text' value=''>\n<br/> "
  @dele_button_field "<span><button class='btn btn-default btn-xs' id='dele_button_ID' name='dele_button_ID' type='submit'>Delete</button></span>\n"
  @save_button_field "<span><button class='btn btn-default btn-xs' id='save_button_ID' name='save_button_ID' type='submit'>Save</button></span>\n"
  @edit_button_field "<span><button class='btn btn-default btn-xs' id='edit_button_ID' name='edit_button_ID' onclick='window.location.href='/edit/ID';'>Edit</button></span>"
  @new_column_reg ~r/new column <input id='new_column' name='new_column' type='text' value/

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
          "#{key} <input id='#{key}' name='#{key}' type='text' value='#{val}'><br/>\n"
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
    keys = List.delete( keys, "text" )
    str = stringify_keys( keys, map )
    id = String.slice str, 0..23
    str = String.slice str, 24..-1
    str = if str =~ @new_column_reg do
      str # id is the first 24 characters of the string returned by stringify_keys - str is the rest of it
    else
      str <> @new_column_field
    end
    del = String.replace @dele_button_field, "ID", id
    save = String.replace @save_button_field, "ID", id
    edit = String.replace @edit_button_field, "ID", id
    str = str <> del <> save <> edit
    [ { id, str }]
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
    [{ id, str <> save }]
  end

  defp articles do
    cursor = Mongo.find(:article, "my_app_db", %{})
    list = cursor |> Enum.to_list() |> stringify_list
    list ++ empty_row()
  end

  def show_articles do
    try do
      start_mongo()
      articles()
    rescue
      re in RuntimeError -> re
        # case re do
      ["e", "Error: #{ re.message }"] # {:error, {:already_started, #PID<0.451.0>}}
    end
  end

  def show_article( id ) do
    cursor = Mongo.find(:article, "my_app_db", %{"_id" => id})
    list = cursor |> Enum.to_list()
    article = List.first( list )[ "text" ]
    article
  end

end
