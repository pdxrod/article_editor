defmodule SimpleMongoApp.Utils do
  alias SimpleMongoApp.Base58
  @hex_24_chars_regex ~r/^([a-f0-9]{24})$/
  # One 24-nibble hex id string can be converted into a base 58 string
  @base_58_6_chars_regex ~r/^([1-9a-km-zA-HJ-NP-Z]{6})$/
  # The angel said no l, and they didn't have 0 then
  @base_58_5_chars_regex ~r/^([1-9a-km-zA-HJ-NP-Z]{5})$/
  @base_64_5_chars_regex ~r/^([1-9a-zA-Z=]{5})$/
  @base_64_6_chars_regex ~r/^([1-9a-zA-Z=]{6})$/

  @types ~w[function nil integer binary bitstring list map float atom tuple pid port reference]
  for type <- @types do
    def typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
  end

  def what?( who ) do
    which = typeof who
    str = case which do
          "tuple" ->
            "size #{tuple_size who} elem 0 #{typeof elem(who, 0)} elem #{tuple_size( who ) - 1} #{typeof elem( who, tuple_size(who) - 1 )} "
          "map" ->
            "size #{ length Map.keys(who) } first #{List.first Map.keys(who)} last #{List.last Map.keys(who)} "
          "atom" -> ":#{ who }"
          "integer" -> "#{ who }"
          "datetime" -> "'#{ who }'"
          "binary" -> "'#{ sample who }'"
          "list" -> "list #{ what?( List.first who ) }"
          _ -> ""
        end
    "type #{which} " <> str
  end

  def sample( str ) do
    str = if mt?( str ), do: "                          nothing   to   see   here   ", else: str
    len = String.length str
    if len < 40 do
      str
    else
      avg = trunc( len / 3 ) - 1
      fin = trunc( avg + 17 )
      String.slice( str, avg..fin )
    end
  end

  def recurse( fail, succeed, collection, condition ) do
    case collection do
      [] -> fail
      [head | tail] ->
        cond do
          condition.( head ) -> succeed
          true -> recurse( fail, succeed, tail, condition )
        end
    end
  end

  def timings do
    config = Application.get_env( :simple_mongo_app, :timings )
    config
  end

  def str do
    config = Application.get_env( :simple_mongo_app, :my_config )
    "name #{config[:username]} password #{config[:password]}"
  end

  def mt?( thing ) do
    thing == nil || thing == "" || thing == '' || thing == %{} || thing == [] || thing == {}
  end

  def notmt?( thing ) do
    ! mt?( thing )
  end

  def hex_24_chars_regex do
    @hex_24_chars_regex
  end

  def base_58_6_chars_regex do
    @base_58_6_chars_regex
  end

  def base_58_5_chars_regex do
    @base_58_5_chars_regex
  end

  def base_64_5_chars_regex do
    @base_64_5_chars_regex
  end

  def base_64_6_chars_regex do
    @base_64_6_chars_regex
  end

  def begin_function( fun, id \\ "127.0.0.1" ) do
    now = System.os_time(:millisecond)
    if nil != id && id =~ hex_24_chars_regex() do
      debug "#{fun} started #{now}", 2
    end
    now
  end

  def end_function( fun, then, id \\ "127.0.0.1" ) do
    if nil != id && id =~ hex_24_chars_regex() do
      now = System.os_time(:millisecond)
      milli = now - then
      debug "#{fun} took #{milli} milliseconds", 2
    end
  end

  def debugging() do
    Application.get_env( :simple_mongo_app, :debugging )
  end

  def debug( str, mode \\ 1 ) do
    if debugging() && mode > 2 do
      IO.puts "#{str}"
      { :ok, file } = File.cwd()
      file = file <> "/article_editor.log"
      tuple = File.read file # If it isn't there, it says {:error, :enoent}
      contents = if :enoent == elem( tuple, 1 ), do: "", else: elem( tuple, 1 )
      contents = if nil == contents, do: "", else: contents
      contents = contents <> str <> "\n"
      File.write file, contents
      contents
    end
  end

  def debug_ids( keys, map ) do
    case keys do
      [] -> ""
      [hd | tl] ->
        debug "debug_ids/2: map is #{ typeof map } and hd is #{ hd } [#{ typeof hd }] ", 1
        val = if "datetime" == hd do
                "datetime"
              else
                if "binary" == typeof( hd ), do: map[hd], else: "datetime"
              end
        "#{hd} -> #{ debug_ids val } "  <> debug_ids( tl, map )
    end
  end

  def debug_ids( obj ) do
    case typeof( obj ) do
      "nil" -> "nil"
      "atom" -> ":#{ obj }"
      "integer" -> "#{ obj }"
      "datetime" -> "#{ obj }"
      "binary" -> "'#{ sample obj }'"
      "tuple" -> "tuple 0 #{elem obj, 0} "
      "map" ->
        debug_ids( Map.keys( obj ), obj )
      "list" ->
        case obj do
          [] -> ""
          [hd | tl] ->
            debug_ids( hd ) <> debug_ids( tl )
        end
      _ -> "UNKNOWN TYPE #{typeof obj} "
    end
  end

  def chunk( chunk_size, text, last_chunk \\ 1 ) do
    debug "chunk #{chunk_size} #{String.length text} #{last_chunk}", 2
    if chunk_size >= String.length text do
      [ text ]
    else
      slice_start = 0
      slice_end = (slice_start + chunk_size) - 1
      next_slice_start = slice_end + 1
      end_of_text = String.length( text )
      debug "chunk slice indeces #{slice_start}..#{slice_end} #{next_slice_start} #{end_of_text}", 2
      next_text = String.slice text, next_slice_start..end_of_text
      [ String.slice( text, slice_start..slice_end ) ] ++ chunk( chunk_size, next_text, last_chunk + 1 )
    end
  end

  def index( list, num ) do
    case list do
      [] -> []
      _ -> [List.first list]
    end
  end

  def selection( list, range ) do
    pages = Enum.to_list range
    if [] == list || [] == pages do
      []
    else
      pghd = [hd pages]
      pgtl = tl pages
      lstl = tl list
      hdpgtl = if 1 < length( pages ), do: [hd pgtl], else: []
      index( list, pghd ) ++ index( lstl, hdpgtl )
    end
  end

end
