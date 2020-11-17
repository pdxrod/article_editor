defmodule SimpleMongoAppWeb.PageController do
  use SimpleMongoAppWeb, :controller
  alias BSON.ObjectId

  @save_button_reg ~r/save_button_.+/
  @dele_button_reg ~r/dele_button_.+/
  @text_button_reg ~r/text_button_.+/
  @todo_button_reg ~r/.{4}_button_.+/
  @textarea_reg ~r/textarea_.+/
  @debugging true

  defp debug( str ) do
    if @debugging, do: IO.puts "\n#{str}"
  end

  defp delete( id ) do
    Mongo.delete_one(:article, "my_app_db", %{_id: id})
  end

  def already_exists_with_this_name_and_classification?( args ) do
    if nil == args[ "classification" ] || nil == args[ "name" ] do
      false
    else
      id = find_id( Map.keys( args ), args, @save_button_reg )
      if id do
        false # If the id exists, we're updating an article, so the name & classification can stay the same
      else    # Otherwise, we're creating a new one, so it can't use an existing name/classifcation combo
        map = %{ classification: args[ "classification" ], name: args[ "name" ] }
        cursor = Mongo.find(:article, "my_app_db", map)
        list = cursor |> Enum.to_list()
        list != []
      end
    end
  end

  defp replace( id, params ) do # Also creates a new article from the empty form
    old_article = %{_id: id}
    new_column = find_new_column params
    new_article = remove_unwanted_keys params
    new_map = if "" == new_column do
      %{}
    else
      %{new_column => ""}
    end
    new_article = Map.merge( new_article, new_map )
    {:ok, new_article} = Mongo.find_one_and_replace(:article, "my_app_db", old_article, new_article, [return_document: :after, upsert: :true])
#     {:ok, new_article} = Mongo.find_one_and_update( :article, "my_app_db", old_article,  %{"$set" => new_article}, [return_document: :after])
    new_article
  end

  defp find_id( keys, map, reg ) do
    case keys do
      [] ->
        nil
      [hd | tl] ->
        if hd =~ reg do
          String.slice( hd, 12..-1)
        else
          find_id tl, map, reg
        end
    end
  end

  defp find_button_key( keys ) do
    case keys do
      [] -> @decaf00f
      [hd | tl] ->
        if hd =~ @todo_button_reg do
          hd
        else
          find_button_key tl
        end
    end
  end

  defp find_new_column( args ) do
    new_column = args["new_column"]
    if new_column == nil do
      ""
    else
      String.trim new_column
    end
  end

  defp remove_unwanted_keys( args ) do
 # "_csrf_token" => "UCwUFn5PbBw9FSNpMR0aRyk8MDkdOgYa4gECM56NsyaZCUhqfIwKQPVE",
 # "_id" => "5fa793f09dad02e8eae18e33", "classification" => "man", "page" => "<div>TinyMCE</div>",
 # "name" => "John", "new_column" => "gender", "save_button_5fa793f09dad02e8eae18e33" => ""
   map = Map.delete( args, "_csrf_token" )
   map = Map.delete( map, "new_column" )
   key = find_button_key( Map.keys( map ))
   Map.delete( map, key )
  end

  # This 'id = id <> <<0>>' turns "5f9d79c5a9f74f0bfb2cb5cc" into
  # <<53, 102, 57, 100, 55, 97, 100, 99, 97, 57, 102, 55, 52, 102, 48, 99, 54, 98, 57, 52, 54, 50, 51, 98, 0>>
  defp make_id_list_and_obj( id ) do
    id_list = id <> <<0>>
    obj_id = %ObjectId{ value: id }
    { id_list, obj_id }
  end

  defp find_str_key( keys ) do
    Enum.find( keys, fn( element ) ->
      match?( "str", element )
    end)
  end

# This is a bit redundant, but it's easier to read than a nest of elses
  defp params?( params ) do
    save = find_id( Map.keys( params ), params, @save_button_reg )
    dele = find_id( Map.keys( params ), params, @dele_button_reg )
    str = find_str_key Map.keys( params )
    result = if save, do: :save, else: nil
    result = if dele, do: :dele, else: result
    result = if str, do: :str, else: result
    result
  end

# %{classification" => "man", "name" => "Joan", "new_column" => "gender", "save_button_5f9d7adca9f74f0c6b94623b" => ""}
# This function does more than just 'analyze' the params - it changes the database
  defp analyze_params( params ) do
    case params?( params ) do
      :save ->
        id = find_id( Map.keys( params ), params, @save_button_reg )
        new_article = replace id, params
        c = new_article["classification"]
        n = new_article["name"]
        debug "Found and replaced article #{id}, #{c}: #{n}"
      :dele ->
        id = find_id( Map.keys( params ), params, @dele_button_reg )
        delete id
        debug "Found and deleted article #{id}"
      :str ->
        str = params[ "str" ]
        debug "Found parameter str - it's #{ str }"
      _ ->
        debug "Not found - this just means displaying the page, not hitting a button"
    end
  end

  defp remove_unneeded_keys( args ) do
    map = Map.delete( args, "id" )
    map = Map.delete( map, "_csrf_token" )
    key = find_button_key( Map.keys( map ))
    map = Map.delete( map, key )
    key = find_textarea_key( Map.keys( map ))
    Map.delete( map, key )
  end

  defp find_textarea_key( keys ) do
    case keys do
      [] -> nil
      [hd | tl] ->
        if hd =~ @textarea_reg do
          hd
        else
          find_textarea_key tl
        end
    end
  end

# %{"_csrf_token" => "LwA_GUJNH2R9K29nEQ4AYX4kNyUlBh4FKKnLq7E63G-TcFrW1QpWilNZ", "id" => "21551e404523e2ea57799d82",
# "text_button_21551e404523e2ea57799d82" => "", "textarea_21551e404523e2ea57799d82" => "<p>hello mce</p>"}
  defp update( id, params ) do
    textarea_key = find_textarea_key Map.keys( params )
    text = params[ textarea_key ]                       # Get the new HTML text from the textarea on the edit page
    old_article = Mongo.find_one(:article, "my_app_db", %{_id: id})
    new_article = remove_unneeded_keys params
    new_article = Map.merge( new_article, old_article ) # This gets the name, etc. from the previous version, but also the old HTML text
    new_article = Map.put( new_article, "page", text )  # So put the new text in it in its place, and save it
    {:ok, new_article} = Mongo.find_one_and_replace(:article, "my_app_db", old_article, new_article, [return_document: :after, upsert: :true])
    new_article
  end

# This function does more than just 'analyse' the params - it changes the database
  defp analyse_params( params ) do
    id = params[ "id" ]
    if id == nil do
      debug "Not found - this just means displaying the edit page, not hitting the button"
    else
      textarea_key = find_textarea_key Map.keys( params )
      if textarea_key == nil do
        debug "Not found - this just means displaying the editor, not hitting any buttons"
      else
        new_article = update id, params
        t = new_article[ "page" ]
        debug "Found and replaced article #{id} with '#{t}'"
      end
    end
    id
  end

# ------------------------------------------------------------------------------
# private ^ public v

    def edit( conn, params ) do
      debug "edit"
      id = analyse_params params
      conn = assign(conn, :id, id)
      conn = render conn, "edit.html"
      debug "edit params id #{ id }"
      conn
    end

    def index(conn, params) do
      debug "index()"
      if already_exists_with_this_name_and_classification?( params ) do
        debug "This article already exists"
        conn = assign(conn, :error, "This article already exists")
      else

        analyze_params params
        conn = assign(conn, :error, nil)
      end
      render conn, "index.html"
    end

    def find( conn, params ) do
      debug "find()"
      analyze_params params
      str = find_str_key Map.keys( params )
      conn = if str do
        str = params[ "str" ]
        debug "find() - parameter str #{str}"
        assign( conn, :str, str )
      else
        debug "find() - no parameter str"
        assign( conn, :str, "" )
      end
      render conn, "find.html"
    end

end
