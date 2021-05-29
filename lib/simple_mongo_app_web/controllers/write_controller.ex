defmodule SimpleMongoAppWeb.WriteController do
  use SimpleMongoAppWeb, :controller
  alias BSON.ObjectId
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.DatetimeUtils
  alias SimpleMongoApp.LoginUtils
  alias SimpleMongoApp.MemoryDb
  alias SimpleMongoApp.Base58
  plug BasicAuth, use_config: {:simple_mongo_app, :your_config}

  @save_button_reg ~r/save_button_.+/
  @dele_button_reg ~r/dele_button_.+/
  @back_button_reg ~r/back_button_.+/
  @textarea_reg ~r/textarea_.+/

  defp delete( id ) do
    MemoryDb.delete_one( id )
  end

  defp new_article?( args ) do
    id = HtmlUtils.find_id( Map.keys( args ), args, @save_button_reg )
    exists = MemoryDb.peek( id )
    ! exists
  end

# 1. We are updating an old article - name and classification can stay the same - return false
# 2. We are creating a new article -
#   a. there is no other article in the database with this name and classification - return false
#   b. there is another article in the database with this name and classifcation - return true
  defp already_exists_with_this_name_and_classification?( args ) do
    if nil == args[ "classification" ] || nil == args[ "name" ] do
      Utils.debug "already_exists_with_this_name_and_classification? 1"
      false
    else
      if new_article?( args ) do
        Utils.debug "already_exists_with_this_name_and_classification? 2"
        list = MemoryDb.find( args[ "classification" ], args[ "name" ] )
        Utils.debug "already_exists_with_this_name_and_classification? #{ Enum.count( list ) > 0 }"
        Enum.count( list ) > 0
      else
        Utils.debug "already_exists_with_this_name_and_classification? 3"
        false
      end
    end
  end

  defp trying_to_save_with_no_name_or_classification?( args ) do
    save = HtmlUtils.find_id( Map.keys( args ), args, @save_button_reg )
    case save do
      nil -> false
      _ ->
        (! Utils.mt? args) && (Utils.mt?( args["classification"] ) || Utils.mt?( args["name"] ))
      end
  end

  defp find_button_key( keys ) do
    case keys do
      [] -> nil
      [hd | tl] ->
        if hd =~ HtmlUtils.todo_button_regex() do
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

  defp find_new_value( args ) do
    new_value = args["new_value"]
    if new_value == nil do
      ""
    else
      String.trim new_value
    end
  end

  defp remove_unwanted_keys( args ) do
 # "_csrf_token" => "UCwUFn5PbBw9FSNpMR0aRyk8MDkdOgYa4gECM56NsyaZCUhqfIwKQPVE",
 # "_id" => "5fa793f09dad02e8eae18e33", "classification" => "man", "page" => "<div>TinyMCE</div>",
 # "name" => "John", "new_column" => "gender", "save_button_5fa793f09dad02e8eae18e33" => ""
   map = Map.delete( args, "_csrf_token" )
   map = Map.delete( map, "new_column" )
   map = Map.delete( map, "new_value" )
   map = Map.delete( map, "short_id" )
   map = Map.delete( map, "date" )
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

  defp remove_unneeded_keys( args ) do
    map = Map.delete( args, "_id" )
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

  defp update_from_index_params( id, params ) do # Also creates a new article from the empty form
    new_column = find_new_column params
    new_value = find_new_value params
    sid = Base58.hex_id_to_short_id id
    new_article = remove_unwanted_keys params
    Utils.debug "write_controller update_from_index_params date <#{params['date']}>", 2
    datetime = DatetimeUtils.string2datetime params[ "date" ]
    datetime_map = %{ "datetime" => datetime }
    new_article = Map.merge( new_article, datetime_map )
    new_map = if "" == new_column do
      %{"short_id" => sid}
    else
      %{new_column => new_value, "short_id" => sid}
    end
    new_article = Map.merge( new_article, new_map )
    Utils.debug "WriteController.update_from_index_params() creating or replacing article id #{ id }, name '#{ new_article["name"] }', short id '#{ new_article["short_id"] }'", 2
    MemoryDb.put(id, new_article)
  end

# %{"_csrf_token" => "LwA_GUJNH2R9K29nEQ4AYX4kNyUlBh4FKKnLq7E63G-TcFrW1QpWilNZ", "id" => "21551e404523e2ea57799d82",
# "text_button_21551e404523e2ea57799d82" => "", "textarea_21551e404523e2ea57799d82" => "<p>hello mce</p>"}
  defp update_from_edit_params( id, params ) do
    datetime = DatetimeUtils.string2datetime params[ "datetime" ]
    textarea_key = find_textarea_key Map.keys( params )
    text = params[ textarea_key ]                       # Get the new HTML text from the textarea on the edit page
    text = String.replace text, "&rdquo;", "”"          # Needed because rdquo doesn't always get unescaped in auto_url! (but ldquo always does?!)
    id_map = MemoryDb.peek( id )
    new_article = remove_unneeded_keys params
    datetime_map = %{ "datetime" => datetime }
    new_article = Map.merge( new_article, datetime_map )
    new_article = Map.merge( new_article, id_map ) # This gets the name, etc. from the previous version, but also the old HTML text
    new_article = Map.put( new_article, "page", text )  # So put the new text in it in its place, and save it
    sid = if id =~ Utils.base_58_5_chars_regex() do
            id
          else
            Base58.hex_id_to_short_id id
          end
    sid_map = %{"short_id" => sid}
    new_article = Map.merge( new_article, sid_map )
    Utils.debug "WriteController.update_from_edit_params() old #{Utils.debug_ids id_map} new #{Utils.debug new_article}"
    MemoryDb.put( id, new_article )
  end

  defp analyse_edit_params_and_save( conn, params ) do
    map = MemoryDb.id_and_short_id params[ "id" ]
    id = map["id"]
    Utils.debug "write_controller analyse_edit_params_and_save/2 id '#{id}'", 2
    id = if id == nil do
      nil
    else
      textarea_key = find_textarea_key Map.keys( params )
      if nil == textarea_key do
        Utils.debug "$$$ WriteController analyse_edit_params_and_save textarea_key not found - this just means displaying the editor, not hitting any buttons", 2
      else
        Utils.debug "$$$ WriteController updating article #{id}", 2
        new_article = update_from_edit_params id, params
      end
      id
    end
    id
  end

# This is a bit redundant, but it's easier to read than a nest of elses
  defp params?( params ) do
    save = HtmlUtils.find_id( Map.keys( params ), params, @save_button_reg )
    dele = HtmlUtils.find_id( Map.keys( params ), params, @dele_button_reg )
    str = params["s"]
    classification = params["c"]
# It's important to get these in the right order, because param 'c' can be set when you're doing something other than listing the articles in classification 'c'
    result = if dele, do: :dele, else: nil
    result = if str, do: :search, else: result
    result = if classification, do: :classification, else: result
    result = if save, do: :save, else: result
    Utils.debug "params? returns '#{result}'", 2
    result
  end

  defp try_to_save_from_index_params( conn, args ) do
    id = HtmlUtils.find_id( Map.keys( args ), args, @save_button_reg )
    if trying_to_save_with_no_name_or_classification?( args ) do
      assign(conn, :error, "Name and classification must have values")
    else
      if already_exists_with_this_name_and_classification?( args ) do
        assign(conn, :error, "This article already exists")
      else
        args = Map.delete args, "c" # A 'c' could've gotten in there if we're on a 'category' page - it's the same as 'classification'
        id_map = %{"_id" => id}
        args = Map.merge args, id_map
        args = if id =~ Utils.hex_24_chars_regex() do
                  sid = Base58.hex_id_to_short_id id
                  sid_map = %{"short_id" => sid}
                  Map.merge args, sid_map
                else
                  args
                end
        new_article = update_from_index_params id, args
        c = new_article["classification"]
        n = new_article["name"]
        h = new_article["page"]
        d = args["datetime"]
        Utils.debug "Saved article #{id}, #{c}: #{n}, page '#{Utils.sample h}', datetime '#{ d }'", 2
        conn = assign(conn, :error, nil)
        conn
      end
    end
  end

  defp analyze_index_params_and_save( conn, args ) do
    Utils.debug "\nanalyze_index_params_and_save()", 2
    case params?( args ) do

      :save ->
        Utils.debug "\n$$$$$$$$$$$$$$$$$$$$$$$\nCalling try_to_save_from_index_params :save #{Utils.debug_ids args}\n", 2
        try_to_save_from_index_params conn, args

      :dele ->
        Utils.debug "Calling delete", 2
        id = HtmlUtils.find_id( Map.keys( args ), args, @dele_button_reg )
        delete id
        Utils.debug "\nanalyze_index_params_and_save - found and deleted article #{id}", 2
        assign(conn, :error, nil)

      :search ->
        Utils.debug "search", 2
        str = args[ "s" ]
        Utils.debug "Found parameter s - it's #{ str }"
        assign(conn, :error, nil)

      :classification ->
        Utils.debug "classification", 2
        assign(conn, :error, nil)
        str = args[ "c" ]
        Utils.debug "Found parameter c - it's #{ str }"
        assign(conn, :c, str)

      _ ->
        Utils.debug "Not found - this just means displaying a page, not hitting a button"
        page_num = args[ "p" ]
        assign(conn, :p, page_num)
        assign(conn, :error, nil)
    end
  end

  defp deal_with_timed_out_or_not_logged_in( conn, args ) do
    Utils.debug "login deal_with_timed_out_or_not_logged_in()"
# Even with the correct combination, you can't get in if you have made five failed login attempts in the last 24 hours
    if LoginUtils.more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours?( conn ) do
      Utils.debug "more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours? is true"
      render conn, "login.html"
    else
      Utils.debug "more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours? is false"
      if LoginUtils.logging_in? args do
        if LoginUtils.correct_username_and_password?( args ) do
          Utils.debug "correct username and password", 2
          LoginUtils.save_login_time!( conn )
          Utils.debug "saved login time", 2
          render conn, "index.html"
        else
          Utils.debug "not correct_username_and_password", 2
          LoginUtils.increment_unsuccessful_logins!( conn )
          render conn, "login.html"
        end
      else
        Utils.debug "not logging in"
# It could be that the user just refreshed a page - there's no name or password in the params
        render conn, "login.html"
      end
    end
  end

# ------------------------------------------------------------------------------
# private ^ public v

    def edit( conn, params ) do
      Utils.debug "edit()", 2
      args = HtmlUtils.trim_vals params
      if LoginUtils.logged_in_and_not_timed_out?( conn ) do
        LoginUtils.save_login_time! conn
        id = analyse_edit_params_and_save conn, args
        if MemoryDb.valid_id? id do
          conn = assign(conn, :id, id)
          timings = Utils.timings()
          timing = elem( timings, 0 )
          conn = assign(conn, :timing, timing)
          render conn, "edit.html"
        else
          assign(conn, :error, "Invalid value '#{ id }'")
          conn |> Phoenix.Controller.redirect(to: "/write")
        end
      else
        conn |> Phoenix.Controller.redirect(to: "/write")
      end
    end

    def index(conn, params) do
      Utils.debug "index()", 2
      args = HtmlUtils.trim_vals params
      if LoginUtils.logged_in_and_not_timed_out?( conn ) do
        Utils.debug "login LoginUtils.logged_in_and_not_timed_out?() true", 2
        LoginUtils.save_login_time! conn
        Utils.debug "index about to analyze_index_params_and_save", 2
        conn = analyze_index_params_and_save conn, args
        Utils.debug "index after analyze_index_params_and_save", 2
        render conn, "index.html"
      else
        Utils.debug "login LoginUtils.logged_in_and_not_timed_out?() false", 2
        login conn, args
      end
    end

    def find( conn, params ) do
      args = HtmlUtils.trim_vals params
      id = args["id"]
      a = LoginUtils.logged_in_and_not_timed_out?( conn )
      args = Map.merge args, %{"a" => "#{a}"}
      result = HtmlUtils.find conn, args
      result
    end

    def login( conn, params ) do
      Utils.debug "login()", 2
      args = HtmlUtils.trim_vals params
      if LoginUtils.logged_in_and_not_timed_out?( conn ) do
        Utils.debug "login LoginUtils.logged_in_and_not_timed_out?() true - saving login time", 2
        LoginUtils.save_login_time! conn
        Utils.debug "login LoginUtils.logged_in_and_not_timed_out?() true - after saving login time", 2
        index conn, args
      else
        Utils.debug "login LoginUtils.logged_in_and_not_timed_out?() false", 2
        deal_with_timed_out_or_not_logged_in( conn, args )
      end
    end

end
