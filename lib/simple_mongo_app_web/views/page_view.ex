defmodule SimpleMongoAppWeb.PageView do
  use SimpleMongoAppWeb, :view

  #  @dele_button_field "<span><button class='btn btn-default btn-xs' id='dele_button_ID' name='dele_button_ID' type='submit' style='background-color: #ff99cc; width: 80px;'>Delete</button></span>\n"
  @dele_button_field """
  <a href='/' onclick=\"if (confirm('are you sure?')) { var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;
  var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', 'dele_button_ID'); m.setAttribute('value', 'delete'); m.setAttribute('id', 'dele_button_ID'); f.appendChild(m);
      m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_csrf_token'); m.setAttribute('value', 'CSRF_TOKEN'); m.setAttribute('id', '_csrf_token');   f.appendChild(m);
  f.submit(); }; return false;\"
  style='float: right; background-color: #db7093; text-align: center; color: #ffffff; padding: 2px; margin: 3px; margin-right: 12px; width: 80px;'>Delete</a>
  """
  @save_button_field "<span><button class='btn btn-default btn-xs' id='save_button_ID' name='save_button_ID' type='submit' style='padding: 2px; margin: 3px; background-color: #00ffff; width: 80px;'>Save</button></span>\n"
  @edit_button_field "<span><button class='btn btn-default btn-xs' id='edit_button_ID' name='edit_button_ID' onclick=\"window.location = '/edit/ID'; return false;\" style='padding: 2px; margin: 3px; background-color: #66ffcc; width: 80px;'>Edit</button></span>"
  @new_column_field "<label style='width: 29%; float: left' for='new_column'>new column?</label> <input style='width: 69%; float: left;' id='new_column' name='new_column' type='text' value=''><br/>\n "
  @new_column_reg ~r/<label.+new column.+input.+new_column.+/
  @debugging false

  defp debug( str ) do
    if @debugging, do: IO.puts "\n#{str}"
  end

  @types ~w[function nil integer binary bitstring list map float atom tuple pid port reference]
  for type <- @types do
    defp typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
  end

  def urlify( str ) do
    down = String.downcase str
    if String.starts_with?( down, "http") do
      "<a href='#{ str }'>#{ str }</a>"
    else
      if String.starts_with?( down, "<a href") do
        str
      else
        "<a href='http://#{ str }'>#{ str }</a>"
      end
    end
  end

  defp htmlify_key_val( key, val ) do
    "<span><label style='width: 29%; float: left' for='#{key}'>#{key}</label> <input style='width: 69%; float: left;' id='#{key}' name='#{key}' type='text' value='#{val}'></span><br/>\n"
  end

  defp stringify_key_val( key, val ) do
    if val == nil do
      ""
    else
      if typeof( val ) == "binary" do
        case key do
          "_id" ->
            val
          "page" ->
            "<textarea id='page' name='page' style='display: none;'>#{val}</textarea><br/>\n"
          "url" ->
            htmlify_key_val( key, val ) <> urlify( val ) <> "<br/>\n"
          _ ->
            htmlify_key_val( key, val )
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
      [_ | tl] ->
        key = List.first( keys )
        stringify_key_val( key, map[ key ]) <> stringify_keys( tl, map )
    end
  end

  defp stringify_map( map ) do
    keys = Map.keys( map )
    str = stringify_keys( keys, map )
    id = String.slice str, 0..23
    str = String.slice str, 24..-1
    str = if str =~ @new_column_reg do
      str
    else
      str <> @new_column_field
    end
    del = String.replace @dele_button_field, "ID", id
    csrf_token = Phoenix.Controller.get_csrf_token()
    del = String.replace del, "CSRF_TOKEN", csrf_token
    save = String.replace @save_button_field, "ID", id
    edit = String.replace @edit_button_field, "ID", id
    str = str <> "<div>" <> save <> edit <> del <> "</div><br/>\n"
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
    label = "<div><b>New article</b></div><br/>\n"
    [ { id, label <> str <> save } ]
  end

  defp articles do
    cursor = Mongo.find(:article, "my_app_db", %{})
    list = cursor |> Enum.to_list() |> stringify_list
    list ++ empty_row()
  end

# What I really want to do is get rid of all the HTML except the contents of the value fields in
# the inputs classification and name, plus any 'new columns', and the value field in hidden input 'page'
  def get_values( html, reg ) do
    one_line = String.replace html, "\n", " "
    one_line = String.replace one_line, ~r/<button.+\/button>/, ""
    one_line = String.replace one_line, ~r/style='.+?'/, ""
    values = Regex.scan reg, one_line
    values = List.flatten values
    str = Enum.join values
    str = String.replace str, "value=", ""
    str = String.replace str, "''", " "
    str = String.replace str, "\"\"", " "
    if String.contains?( str, "hello" ), do:  debug "str contains hello - index: #{elem(:binary.match(str, "hello"), 0)}\n"
    str
  end

  defp select_articles( articles, str ) do
    case articles do
      [] -> []
      [hd | tl] ->
        article = elem( hd, 1 ) # Sometimes it's value='value', sometimes it's value="value" (double quotes)
        quotes =       get_values( article, ~r/value='.+'/ )
        doublequotes = get_values( article, ~r/value=".+"/ )
        bothquotes = quotes <> " " <> doublequotes
        if String.contains?( bothquotes, str ) do
          [ hd ] ++ select_articles( tl, str )
        else
          select_articles tl, str
        end
    end
  end

# ------------------------------------------------------------------------------
# private ^ public v

  def show_articles( str ) do
    try do
      select_articles articles(), str
    rescue
      re in RuntimeError -> re
      [ { "decaf0ff", "Error: #{ re.message }" } ]
    end
  end

  def display_page( html ) do
    if nil == html do
      ""
    else
      page = String.replace( html, "<html", "<div" )
      page = String.replace( page, "</html", "</div" )
      page = String.replace( html, "<body", "<div" )
      page = String.replace( page, "</body", "</div" )
      page
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
