defmodule SimpleMongoAppWeb.PageController do
  use SimpleMongoAppWeb, :controller
  alias BSON.ObjectId

  @save_button_reg ~r/save_button_.+/
  @dele_button_reg ~r/dele_button_.+/
  @text_button_reg ~r/text_button_.+/
  @todo_button_reg ~r/.{4}_button_.+/
  @textarea_reg ~r/textarea_.+/
  @decaf0ff "decaf0ff"

  defp delete( id ) do
    Mongo.delete_one(:article, "my_app_db", %{_id: id})
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
        @decaf0ff
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
    String.trim new_column
  end

  defp remove_unwanted_keys( args ) do
 # "_csrf_token" => "UCwUFn5PbBw9FSNpMR0aRyk8MDkdOgYa4gECM56NsyaZCUhqfIwKQPVE",
 # "_id" => "5fa793f09dad02e8eae18e33", "classification" => "man", "text" => "<div>TinyMCE</div>",
 # "name" => "John", "new_column" => "gender", "save_button_5fa793f09dad02e8eae18e33" => ""
   map = Map.delete( args, "_csrf_token" )
   map = Map.delete( map, "new_column" )
   key = find_button_key( Map.keys( map ))
   Map.delete( map, key )
  end

  # This 'id = id <> <<0>>' turns "5f9d79c5a9f74f0bfb2cb5cc" into
  # <<53, 102, 57, 100, 55, 97, 100, 99, 97, 57, 102, 55, 52, 102, 48, 99, 54, 98, 57, 52, 54, 50, 51, 98, 0>>
  def make_id_list_and_obj( id ) do
    id_list = id <> <<0>>
    obj_id = %ObjectId{ value: id }
    { id_list, obj_id }
  end

 # %{classification" => "man", "name" => "Joan", "new_column" => "gender", "save_button_5f9d7adca9f74f0c6b94623b" => ""}
  defp analyze_params( params ) do
    id = find_id( Map.keys( params ), params, @save_button_reg )
    if id == @decaf0ff do
      id = find_id( Map.keys( params ), params, @dele_button_reg )
      if id == @decaf0ff do
        IO.puts "Not found - this just means displaying the page, not hitting a button"
      else
        delete id
        IO.puts "Found and deleted article #{id}"
      end
    else
      new_article = replace id, params
      c = new_article["classification"]
      n = new_article["name"]
      IO.puts "Found and replaced article #{id} with #{c}: #{n}"
    end
  end

    def index(conn, params) do
      analyze_params params
      render conn, "index.html"
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
      [] -> @decaf0ff
      %{"id" => _key} -> @decaf0ff
      [hd | tl] ->
        if hd =~ @textarea_reg do
          hd
        else
          find_textarea_key tl
        end
    end
  end

# %{"_csrf_token" => "LwA_GUJNH2R9K29nEQ4AYX4kNyUlBh4FKKnLq7E63G-TcFrW1QpWilNZ", "id" => "f74f896e704204874c9511dd",
# "text_button_21551e404523e2ea57799d82" => "", "textarea_21551e404523e2ea57799d82" => "<p>hello mce</p>"}
  defp update( id, params ) do
    textarea_key = find_textarea_key params
    text = params[ textarea_key ]
    old_article = Mongo.find_one(:article, "my_app_db", %{_id: id})
    new_article = remove_unneeded_keys params
    new_article = Map.put( new_article, "text", text )
    {:ok, new_article} = Mongo.find_one_and_replace(:article, "my_app_db", old_article, new_article, [return_document: :after, upsert: :true])
    new_article
  end

  defp analyse_params( params ) do
    id = params[ "id" ]
    if id == nil do
      IO.puts "Not found 1 - this just means displaying the edit, not hitting the button"
    else
      textarea_key = find_textarea_key params
      if textarea_key == @decaf0ff do
        IO.puts "Not found 2 - this just means displaying the edit, not hitting the button"
      else
        new_article = update id, params
        t = new_article[ "text" ]
        IO.puts "Found and replaced article #{id} with #{t}"
      end
    end
  end

    def edit( conn, params ) do
      key = find_button_key( Map.keys( params ))
      analyse_params params
      conn = render conn, "edit.html"
      IO.puts "edit params #{params[ key ]}"
      conn
    end

end
