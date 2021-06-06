defmodule SimpleMongoApp.MemoryDb do
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.DatetimeUtils
  alias SimpleMongoApp.Base58
  alias SimpleMongoApp.MongoDb

  @moduledoc """

STARTUP
  MDb fills its map with all articles from the data in the database, including ones with IPs as IDs
  / gets all articles from MDb map, except the ones with IPs, and displays them
  All requests for an article from /, with or without c or s, or /read/ID, gets the article from the MDb map and displays it
  /write gets all articles from MDb map, except the ones with IPs, and displays them
  All requests for an article from /write, with or without c or s, or /write/ID, gets the article from the MDb map and displays it
  All saves from /write, with or without c, or /write/ID
    first sees if the article is in the MDb map
      if it is, compare its contents with the article being saved
        if they are identical, do nothing
        if they are different, go through SAVE below
      if it isn't, go through SAVE below
  Delete - delete it from the MDb map

LOGGING IN
  If someone tries to log in, go through the procedure 'logged in and not timed out', 'login time not in future', 'logging in?' etc.
  using the IP records stored in the MDb map
  If any IP record is written to in the MDb map, go through SAVE below

SAVE
  Save the article in the MDb map - the procedure is the same whether it's an old or a new article
  BackgroundSaver saves articles which are new or have changed from the MDb map to the database at intervals
  If an article has been deleted from the MDb map, there is no entry for its id in the BackroundSaver map, so BacgroundSaver deletes it from Mongo


  """

  def start_link do
    Agent.start_link(fn -> %{ } end, name: __MODULE__ )
  end

  def fill do
    list = MongoDb.articles( )
    put_articles list
  end

  defp finish do
    Utils.debug "MemoryDb finished putting articles", 2
  end

  defp put_articles( articles ) do
    case articles do
      [] -> finish()
      [ hd | tl ] ->
        Utils.debug "MemoryDb.put_articles hd is a #{ Utils.typeof hd }"
        id = hd["_id"]
        Utils.debug "MemoryDb.put_articles #{ id }, name '#{ Utils.sample hd["name"] }'"
        put id, hd
        put_articles tl
    end
  end

  def put( id, new_article ) do
    map = id_and_short_id id
    hex = map["id"]
    sid = map["short_id"]
    sid_map = %{ "short_id" => sid }
    article = peek( hex )
    if sid && article, do: article = Map.merge article, sid_map # sid will be nil if id is an ip address
    if article == new_article do
      if id =~ Utils.hex_24_chars_regex() || id =~ Utils.base_58_5_chars_regex(), do: Utils.debug "MemoryDb article exists in map - not putting '#{ hex } #{ sid }' #{Utils.debug_ids new_article}", 2
    else
      if id =~ Utils.hex_24_chars_regex() || id =~ Utils.base_58_5_chars_regex(), do: Utils.debug "MemoryDb article doesn't exist in map - putting '#{ hex } #{ sid }' #{Utils.debug_ids new_article}", 2
      Agent.update(__MODULE__, &Map.put( &1, id, new_article ))
    end
    new_article
  end

  def id_and_short_id( id3 ) do # id3 could be a hex id, a base58 short id, or an ip address
    {id, short_id} =
      cond do
        id3 =~ Utils.base_58_5_chars_regex() ->
          Utils.debug "MemoryDb id_and_short_id with short_id #{ id3 }", 2
          article = find_by_short_id articles(), id3
          { article["_id"], id3 }
        id3 =~ Utils.hex_24_chars_regex() ->
          Utils.debug "MemoryDb id_and_short_id with hex id #{id3}", 2
          short_id = Base58.hex_id_to_short_id id3
          { id3, short_id }
        true -> # It must be one of two other types of id - ipv4 and ipv6, used for recording logins
          Utils.debug "MemoryDb id_and_short_id with neither short_id nor hex id '#{id3}'", 2
          { id3, nil }
      end
    %{"id" => id, "short_id" => short_id}
  end

  def valid_id?( id3 ) do
    cond do
      nil == id3 -> false

      id3 =~ Utils.base_58_5_chars_regex() ->
        nil != peek id3

      id3 =~ Utils.hex_24_chars_regex() ->
        nil != peek id3

      true -> false
    end
  end

  def find_by_short_id( list, short_id ) do
    case list do
      [] -> nil
      [hd | tl] ->
        map = elem( hd, 1 ) # It's a pesky tuple with the id in twice: {"f00baa", %{"_id" => "f00baa", "short_id" => "kS96X"....}}
        if short_id == map["short_id"] do
          map
        else
          find_by_short_id tl, short_id
        end
    end
  end

# The articles whose classification is "sidebar" and whose urls end in either the hex id or the short id of the id of article
  def sidebars( article ) do
    id = article["_id"]
    map = id_and_short_id id
    hex = map["id"]
    sid = map["short_id"]
    list = articles()
    sidebars = Enum.filter( list, fn(article) -> "sidebar" == elem(article, 1)[ "classification" ] end)
    first = Enum.filter( sidebars, fn(article) ->  hex == id_from_url( elem(article, 1)["url"] ) end )
    second = Enum.filter( sidebars, fn(article) -> sid == id_from_url( elem(article, 1)["url"] ) end )
    unique = ( first ++ second ) |> Enum.uniq()
    sorted = Enum.sort( unique, &(DatetimeUtils.datetime2unix( &1 ) > DatetimeUtils.datetime2unix( &2 ) ) )
    Enum.reverse sorted
  end

  def id_from_url( url ) do
    cond do
      nil == url -> nil
      String.contains? url, "/" ->
        list = String.split url, "/"
        List.last list
      true -> nil
    end
  end

  def peek( id ) do
    case id do
      nil -> nil
      _ ->
        map = id_and_short_id id
        hex = map["id"]
        if nil == hex do
          nil
        else
          Agent.get(__MODULE__, &Map.get( &1, hex ))
        end
    end
  end

  def all do
    task = Task.async( fn() -> Agent.get(__MODULE__, fn map -> map end) end)
    the_articles = Task.await task, 2_000
    the_articles
  end

  def articles( ) do
    list = all()
    Utils.debug "MemoryDb articles() ids #{Utils.debug_ids list}", 2
    valid_articles = Enum.filter( list, fn(article) -> HtmlUtils.valid_article_id( elem(article, 0) ) end )
    Utils.debug "MemoryDb valid_articles ids #{Utils.debug_ids valid_articles}", 2
    sorted_articles = Enum.sort( valid_articles, &(DatetimeUtils.datetime2unix( &1 ) > DatetimeUtils.datetime2unix( &2 ) ) )
    Utils.debug "MemoryDb sorted_articles ids #{Utils.debug_ids sorted_articles}", 2
    sorted_articles
  end

  def write_articles() do
    articles()
  end

  def read_articles() do
    Enum.filter( articles(), fn(article) -> "sidebar" != elem(article, 1)[ "classification" ] end)
  end

  def articles_for_page( num_str, read_view ) do
    list = if read_view, do: read_articles(), else: write_articles()
    list = if nil == num_str do
      list
    else
      timings = Utils.timings()
      app = elem( timings, 2 ) # articles per page
      {num, _} = Integer.parse num_str
      range = Utils.range( list, num, app )
      selection = Utils.selection list, range
      range_list = Enum.to_list range
      Utils.debug "MemoryDb.articles_for_page read_view #{read_view} list #{length list} selection #{length selection} num_str #{num_str} range #{List.first range_list}..#{List.last range_list}", 2
      selection
    end
    list
  end

  def number_of_pages( url ) do
    timings = Utils.timings()
    app = elem( timings, 2 ) # articles per page
    list = articles()
    list = if "/" == url, do: read_articles(), else: write_articles()
    len = length list
    app = if app > len, do: len, else: app
    app = if app < 1, do: 1, else: app
    mod = rem( len, app ) # integer division and modulus
    inc = if mod > 0, do: 1, else: 0
    num = div( len, app ) + inc
    Utils.debug "MemoryDb.number_of_pages url '#{url}' len #{len} app #{app} mod #{mod} inc #{inc} num #{num}", 2
    num = if 0 == num, do: 1, else: num
    num
  end

  def find( classification, name ) do
    the_articles = articles()
    list = find_by_classification_and_name( the_articles, classification, name )
    list
  end

  defp find_by_classification_and_name( list, classification, name ) do
    Utils.debug "find_by_classification_and_name #{Utils.debug_ids list}"
    case list do
      [] -> []
      [ hd | tl ] ->
        article = elem( hd, 1 )
        if classification == article[ "classification" ] && name == article[ "name" ] do
          [ hd ] ++ find_by_classification_and_name( tl, classification, name )
        else
          find_by_classification_and_name( tl, classification, name )
        end
    end
  end

  def delete_one( id ) do
    article = peek id
    Utils.debug "MemoryDb.delete_one, before deleting #{id} from map, article is #{Utils.debug_ids article}", 2
    list = Agent.get_and_update(__MODULE__, &Map.pop(&1, id)) # Delete from the write map
    Utils.debug "Agent.get_and_update(__MODULE__, &Map.pop(&1, id)) returns #{Utils.debug_ids list}", 2
    article = peek id
    Utils.debug "MemoryDb.delete_one, after deleting #{id} from map, article is '#{Utils.debug_ids article}', now deleting from Mongo", 2
    MongoDb.delete_one( id )                                  # Delete from the Mongo database
  end

end
