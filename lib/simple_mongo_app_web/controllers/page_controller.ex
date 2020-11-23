defmodule SimpleMongoAppWeb.PageController do
  use SimpleMongoAppWeb, :controller
  alias BSON.ObjectId
  alias SimpleMongoApp.Utils

  @save_button_reg ~r/save_button_.+/
  @dele_button_reg ~r/dele_button_.+/
  @text_button_reg ~r/text_button_.+/
  @todo_button_reg ~r/.{4}_button_.+/
  @textarea_reg ~r/textarea_.+/
  @debugging false

  defp debug( str ) do
    if @debugging, do: IO.puts "\n#{str}"
  end

  defp delete( id ) do
    Mongo.delete_one(:article, "my_app_db", %{_id: id})
  end

  def new_article?( args ) do
    id = find_id( Map.keys( args ), args, @save_button_reg )
    exists = Mongo.find_one(:article, "my_app_db", %{_id: id})
    ! exists
  end

# 1. We are updating an old article - name and classification can stay the same - return false
# 2. We are creating a new article -
#   a. there is no other article in the database with this name and classification - return false
#   b. there is another article in the database with this name and classifcation - return true
  def already_exists_with_this_name_and_classification?( args ) do
    if nil == args[ "classification" ] || nil == args[ "name" ] do
      debug "already_exists_with_this_name_and_classification? 1"
      false
    else
      if new_article?( args ) do
        debug "already_exists_with_this_name_and_classification? 2"
        map = %{ classification: args[ "classification" ], name: args[ "name" ] }
        cursor = Mongo.find(:article, "my_app_db", map)
        list = cursor |> Enum.to_list()
        debug "already_exists_with_this_name_and_classification? #{ Enum.count( list ) > 0 }"
        Enum.count( list ) > 0
      else
        debug "already_exists_with_this_name_and_classification? 3"
        false
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
#   {:ok, new_article} = Mongo.find_one_and_update( :article, "my_app_db", old_article,  %{"$set" => new_article}, [return_document: :after])
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
      [] -> nil
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

# This is a bit redundant, but it's easier to read than a nest of elses
  defp params?( params ) do
    save = find_id( Map.keys( params ), params, @save_button_reg )
    dele = find_id( Map.keys( params ), params, @dele_button_reg )
    str = params["s"]
    classification = params["c"]
    result = if save, do: :save, else: nil
    result = if dele, do: :dele, else: result
    result = if str, do: :search, else: result
    result = if classification, do: :classification, else: result
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
      :search ->
        str = params[ "s" ]
        debug "Found parameter s - it's #{ str }"
      :classification ->
        str = params[ "c" ]
        debug "Found parameter c - it's #{ str }"
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

  defp trim_vals( map ) do
    list = Map.to_list map
    new_list = Enum.map( list, fn(a) -> {String.trim(elem(a, 0)), String.trim(elem(a, 1))} end )
    new_map = Enum.into( new_list, %{} )
    new_map
  end

# ------------------------------------------------------------------------------
# private ^ public v

    def edit( conn, params ) do
      debug "edit()"
      args = trim_vals params
      id = analyse_params args
      conn = assign(conn, :id, id)
      conn = render conn, "edit.html"
      debug "edit params id #{ id }"
      conn
    end

    def index(conn, params) do
      args = trim_vals params
      debug "index()"
      conn =
        if args[ "c" ] do
          debug "c is set - it's #{args["c"]}"
          assign(conn, :c, args[ "c" ])
        else
          if already_exists_with_this_name_and_classification?( args ) do
            debug "This article already exists"
            assign(conn, :error, "This article already exists")
          else
            debug "Either creating a new article, or updating an old one"
            analyze_params args
            assign(conn, :error, nil)
          end
        end
      render conn, "index.html"
    end

# %{"c" => "post", "s" => "_"}
    def find( conn, params ) do
      debug "find()"
      args = trim_vals params
      analyze_params args
      s = args[ "s" ]
# Using underscore is a hack because router thinks find//car is find/car, so it's find/_/car - see index.html Javascript
      s = if "_" == s, do: "", else: s
      c = args[ "c" ]
      c = if "_" == c, do: "", else: c
      conn = if Utils.notmt? s do
        debug "find() - parameter s #{s}"
        conn = assign( conn, :s, s )
        assign( conn, :c, "" )
      else
        debug "find() - no parameter s"
        conn = assign( conn, :s, "" )
        if Utils.notmt? c do
          debug "find() - parameter c #{c}"
          assign(conn, :c, c)
        else
          assign( conn, :c, "" )
        end
      end
      render conn, "find.html"
    end

end
