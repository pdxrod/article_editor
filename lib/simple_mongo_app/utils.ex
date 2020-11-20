defmodule SimpleMongoApp.Utils do

  def endings do
    ["com", "org", "info", "edu", "uk", "au", "tv", "gov", "es", "za", "media", "me", "my", "ru", "ch", "cloud", "tr", "online",
     "international", "vn", "xxx", "co", "coop", "mil", "biz", "nz", "us", "net", "il", "it", "ps", "pn", "de", "fr", "th"]
  end

  @types ~w[function nil integer binary bitstring list map float atom tuple pid port reference]
  for type <- @types do
    def typeof(x) when unquote(:"is_#{type}")(x), do: unquote(type)
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

  def mt?( thing ) do
    thing == nil || thing == "" || thing == '' || thing == %{} || thing == [] || thing == {}
  end

  def notmt?( thing ) do
    ! mt?( thing )
  end

  def contains_href?( text ) do
    down = String.downcase text
    String.contains?( down, "href=" ) || String.contains?( down, "href =" )
  end

  @http_regex ~r/^(http|https|ftp)$/
  @link_regex ~r/[A-Za-z0-9-].+/
  @space_regex ~r/\s+/

  def linkables?( text ) do
    if contains_href? text do
      []
    else
      list = Regex.scan @link_regex, text
      list = List.flatten list
      case list do
        [] -> []
        _ ->
          space = List.first list
          String.split( space, @space_regex )
      end
    end
  end

  def replace_with_link( line, link ) do
    String.replace line, link, "<a href='http://#{ link }'>#{ link }</a>"
  end

  def replace_linkables( list, linkables ) do
    Enum.map( list, &replace_with_link( &1, linkables ) )
  end

  def apply_regexes( line ) do
    linkables = linkables? line
    replaced = cond do
      0 == length( linkables ) ->
        line
      true ->
        linked = replace_linkables [ line ], linkables
        # if length( linked ) > 0 do
        #   Regex.replace @http_regex, List.first( linked ), "<a target='_blank' href='\\1'>\\1</a>"
        # end
    end
    replaced
  end

  def apply_regex( line, function ) do
    function.( line )
  end

  def auto_url!( html ) do
    lines = String.split html, "\n"
    list = Enum.map(lines, fn(line) -> apply_regex( line, &apply_regexes/1 ) end)
    Enum.join list, "\n"
  end

end
