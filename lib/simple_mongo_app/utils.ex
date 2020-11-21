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

  @proto_regex     ~r/(https|http|ftp):\/\//i
  @http_regex      ~r/^(https|http|ftp):\/\/[^\s]+\.[^\s]+$/i # to match string only containing a full url
  @http_line_regex ~r/(https|http|ftp):\/\/[^\s]+\.[^\s]+/i   # to match a line containing a full url
  @url_regex       ~r/^[^\s]+\.[^\s]+$/                       # to match string only containing a url
  @url_line_regex  ~r/[^\s]+\.[^\s]+/                         # to match a line containing a url
  @tag_regex       ~r/(<\/?[A-Z][A-Z0-9]*>)/i
  @space_regex     ~r/\s+/

  def linkables?( text ) do
    if contains_href? text do
      []
    else
          ## Regex.scan ~r/[^\s]+\.[^\s]+/, " hello foo.com bye bar.co.uk " -> [["foo.com"], ["bar.co.uk"]]
      list = Regex.scan @url_line_regex, text
      List.flatten list
    end
  end

  def strip_tags( text ) do
    Regex.replace @tag_regex, text, ""
  end

  def strip_extraneous_quotes_and_tags( text ) do
    stripped = if String.starts_with?( text, ["\"", "'"] ) do
                 String.slice( text, 1..-1 )
               else
                 text
               end
    stripped = if String.ends_with?( stripped, ["\"", "'"] ) do
                 String.slice( stripped, 0..-2 )
               else
                 stripped
               end
    strip_tags stripped
  end

  def replace_linkables( line, linkables ) do
    map = Enum.map( linkables, fn(link) -> link = strip_extraneous_quotes_and_tags( link )
                                           if link =~ @proto_regex do
                                             String.replace line, link, "<a target='_blank' href='#{ link }'>#{ link }</a>"
                                           else
                                             String.replace line, link, "<a target='_blank' href='http://#{ link }'>#{ link }</a>"
                                           end
                                           end )
    Enum.join map, ""
  end

  def apply_regexes( line ) do
    linkables = linkables? line
    replaced = cond do
      0 == length( linkables ) ->
        line
      true ->
        replace_linkables line, linkables
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
