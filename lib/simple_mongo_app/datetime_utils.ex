defmodule SimpleMongoApp.DatetimeUtils do
  alias SimpleMongoApp.Utils

  def format_time( datetime ) do
    len = String.length "2020-12-28"
    if nil == datetime do
      ""
    else
      String.slice( "#{ datetime }", 0..len-1 )
    end
  end

# Get the datetime from { "3b1eb29583bedc882dd0d7f3", %{"_id" => "3b1eb29583bedc882dd0d7f3", "datetime" => ~U[2020-12-28 17:48:53.727Z]...} }
  def datetime2unix( tuple_map ) do
    cond do
      "tuple" != Utils.typeof( tuple_map ) -> 0
      tuple_size( tuple_map ) < 2 -> 0
      nil == elem( tuple_map, 1 )[ "datetime" ] -> 0
      "" == elem( tuple_map, 1 )[ "datetime" ] -> 0
      true ->
        timedate = elem( tuple_map, 1 )[ "datetime" ]
        timestring = "#{ timedate }" # It's either "2020-12-29 14:34:12.052767Z" (in the database) or "2020-12-29 14:34:12" (displayed on the page)
        {:ok, iso8601, 0} = DateTime.from_iso8601( timestring )
        unix = DateTime.to_unix( iso8601 )
        unix
    end
  end

# {:ok, ~U[2020-12-28 17:41:54.550003Z], 0} = DateTime.from_iso8601 "2020-12-28 17:41:54.550003Z"
  def string2datetime( string ) do
    case Utils.typeof( string ) do
      "nil" ->
        Utils.debug "string2datetime #{string} 1", 2
        string2datetime "#{ DateTime.utc_now() }"
      "binary" -> # iso8601 needs the .NNNNNNZ on the end
        Utils.debug "string2datetime #{string} 2", 2
        view_length = String.length "2020-12-28 17:41:54"
        date_length = String.length "2020-12-28"
        full_length = String.length "2021-02-19 13:55:38.000000Z"
        string = String.trim string
        string = if "" == string, do: "#{ DateTime.utc_now() }", else: string
        string = if String.length( string ) <= view_length, do: string <> ".000000Z", else: string
        string = String.slice string, 0..date_length-1
        string = string <> " 00:00:01.000000Z"
        {:ok, timedate, 0} = DateTime.from_iso8601 string
        timedate
      _ ->
        string
    end
  end

end
