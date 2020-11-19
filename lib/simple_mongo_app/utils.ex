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

  def apply_regex( line ) do
    regex = ~r/^(http|https|ftp)$/
    Regex.replace regex, line, "<a target='_blank' href='\\1'>\\1</a>"
  end

  def regex_apply( line, function ) do
    function.( line )
  end

  def auto_url!( html ) do
    lines = String.split html, "\n"
    list = Enum.map(lines, fn(line) -> regex_apply( line, &apply_regex/1 ) end)
    Enum.join list, "\n"
  end

end
