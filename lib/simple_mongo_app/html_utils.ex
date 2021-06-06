defmodule SimpleMongoApp.HtmlUtils do
  use SimpleMongoAppWeb, :controller # Needed to make controller actions in this file work
  alias SimpleMongoApp.MemoryDb
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.DatetimeUtils
  alias SimpleMongoApp.LginUtils
  alias Phoenix.HTML.Safe

  @proto_regex     ~r/(https|http):\/\//i
  @http_regex      ~r/^(https|http):\/\/[^\s]+\.[0-9A-Za-z\/\?&=_-]+$/i # to match string only containing a full url
  @http_line_regex ~r/(https|http):\/\/[^\s]+\.[0-9A-Za-z\/\?&=_-]+/i   # to match a line containing a full url
  @url_regex       ~r/^[^\s]{2,}\.[0-9A-Za-z\/\?&=_-]+$/                # to match string only containing a url
  @url_line_regex  ~r/[^\s]{2,}\.[0-9A-Za-z\/\?&=_-]+/                  # to match a line containing a url
  @image_regex     ~r/^[^\s]+\.[jpg|png|jpeg]+$/                        # to match a reference to an image, eg. the_pic.jpeg
  @space_regex     ~r/\s+|&nbsp;/
  @url_end_regex   ~r/url$/
  @tag_regex       ~r/(<\/?[A-Z][A-Z0-9]*>)/i
  @single_quotes_regex ~r/value='.+/
  @double_quotes_regex ~r/value=".+/
  @button_regex ~r/<button.+\/button>/
  @style_regex ~r/style='.+?'/
  @ip_v4_regex ~r/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/
  @todo_button_regex ~r/.{4}_button_.+/

  # If you can read this, you're on drugs
  @dele_button_field """

  <a href='/write' onclick=\"if (confirm('Delete: are you sure?')) { var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;
  var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', 'dele_button_ID'); m.setAttribute('value', 'delete'); m.setAttribute('id', 'dele_button_ID'); f.appendChild(m);
      m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_csrf_token'); m.setAttribute('value', 'CSRF_TOKEN'); m.setAttribute('id', '_csrf_token');   f.appendChild(m);
  f.submit(); }; return false;\"
  style='background-color: #db7093; text-align: center; color: #ffffff; border-top: 6px; padding: 8px; margin-top: 12px solid white; height: 70px; width: 70px;'>Delete</a>

  """
  @more_button_field "<span><button class='btn btn-default btn-xs' id='edit_button_ID' name='edit_button_ID' onclick=\"window.location = '/read/edit/ID'; return false;\" style='padding: 2px; margin: 1px; background-color: #66ffcc; height: 32px; width: 70px;'>More &rarr;</button></span>"
  @save_button_field "<button class='btn btn-default btn-xs' id='save_button_ID' name='save_button_ID' type='submit' style='padding: 2px; margin: 1px; background-color: #00ffff; height: 32px; width: 70px;'>Save</button>"
  @edit_button_field "<button class='btn btn-default btn-xs' id='edit_button_ID' name='edit_button_ID' onclick=\"window.location = '/write/edit/ID'; return false;\" style='padding: 2px; margin: 1px; background-color: #66ffcc; height: 32px; width: 70px;'>Edit</button>"
  @new_column_field "new column? <input style='width: 35%;;' id='new_column' name='new_column' type='text' value=''> "
  @new_value_field "<input style='width: 45%;;' id='new_value' name='new_value' type='text' value=''> value<br/>\n"
  @new_column_reg ~r/<label.+new column.+input.+new_column.+/
  @textarea_regex ~r/textarea>/

  def safe( html ) do
    Safe.to_iodata html # It used to be called 'safe()' or 'html_escape()', but they thought 'to_iodata()' is clearer
  end

  def save_button_field do
    @save_button_field
  end

  def todo_button_regex do
    @todo_button_regex
  end

  def page( map ) do
    if Utils.mt? map["page"] do
      ""
    else
      map["page"] |> auto_url!()
    end
  end

  def sidebars( articles ) do
    case articles do
      [] -> ""
      [hd | tl] ->
        article = elem hd, 1
        if nil == article["page"] do
          sidebars( tl )
        else
          article["page"] <> "<br/>\n" <> sidebars( tl )
        end
    end
  end

  def sidebar( article ) do
    articles = MemoryDb.sidebars article
    result = sidebars articles
    result || ""
  end

# login times are stored using IPs as IDs, article ids are 12-byte numbers as hex strings
  def valid_article_id( id ) do
    cond do
      nil == id -> false
      id =~ Utils.hex_24_chars_regex() -> true
      true -> false
    end
  end

  def datetime2html( key, val, readonly ) do
    "<span><label style='width: 29%; float: left' for='date'>date gmt</label> <input style='width: 69%; float: left;'" <>
      " id='date' name='date' type='text' value='#{DatetimeUtils.format_time val}' maxlength=10 #{readonly}> </span><br/>\n"
  end

  def stringify_val( key, val, htmlifier ) do
    case key do
      "_id" ->
        ""
      "page" ->
        "<code><textarea id='page' name='page' style='display: none;'>#{safe val}</textarea></code><br/>\n"
      "datetime" ->
        datetime2html( key, val, "" )
      _ ->
        if "#{key}" =~ @url_end_regex do
          htmlifier.( key, val ) <> urlify( val ) <> "<br/>\n" # Put a link to the URL just below the URL
        else
          htmlifier.( key, val )
        end
    end
  end

  def stringify_key_val( key, val, htmlifier, readonly ) do
    v = Utils.typeof val
    k = Utils.typeof key
    Utils.debug "stringify_key_val - key type is #{k}, val type is #{v}"
    result = case v do
        "binary" ->
          if "short_id" == key do
            ""
          else
            stringify_val( key, val, htmlifier )
          end
        _ ->
          if "datetime" == key do
            datetime2html( key, val, readonly )
          else
            "#{ val }"
          end
      end
    Utils.debug "stringify_key_val - returning #{String.slice result, 0..20}"
    result
  end

  def stringify_keys( keys, map, htmlifier, readonly ) do
    case keys do
      [] -> ""
      [_ | tl] ->
        key = List.first( keys )
        str = stringify_key_val( key, map[ key ], htmlifier, readonly ) <> stringify_keys( tl, map, htmlifier, readonly )
        Utils.debug "stringify_keys returns '#{str}'"
        str
    end
  end

  def show_article( id ) do
    article = MemoryDb.peek( id )
    top = summary article
    page = page article
    sidebar = sidebar article
    { top, page, sidebar }
  end

  def htmlify_key_val( key, val, readonly ) do # The write version has readonly set to an empty string
    key = htmlify!( key )
    val = htmlify!( val )
    "<span><label style='width: 29%; float: left' for='#{key}'>#{key}</label> " <>
      "<input maxlength='256' style='width: 69%; float: left;' id='#{key}' name='#{key}' type='text' value='#{val}' " <>
      "#{readonly}></span><br/>\n"
  end

  def htmlify!( val ) do
    val = val |> to_string()
    val = String.replace( val, "'", "&#39;" )
    val
  end

  def write_htmlify_key_val( key, val ) do
    htmlify_key_val( key, val, "" )
  end

  def read_htmlify_key_val( key, val ) do
    htmlify_key_val( key, val, "readonly" )
  end

#  Regex.run( ~r/textarea>/, "hello <textarea>goodbye</textarea>", return: :index) returns [{7, 9}] [The beginning of the first match, and its length??!?]
  defp text_area( html ) do
    tuple_list = Regex.run( @textarea_regex, html, return: :index )
    case tuple_list do
      nil -> ""
      _ ->
        tuple = List.first tuple_list
        num = elem( tuple, 0 ) + elem( tuple, 1 )
        String.slice html, num..-1
    end
  end

  defp stringify_map( id, map, write ) do
    Utils.debug "stringify_map, id is #{ id }, map is #{ Utils.debug_ids map }", 2
    keys = Map.keys map
    Utils.debug "stringify_map before stringify_keys, write #{ write } key 0 #{List.first keys}", 2
    str = if write do
      stringify_keys( keys, map, &write_htmlify_key_val/2, "" )
    else
      stringify_keys( keys, map, &read_htmlify_key_val/2, "readonly" )
    end
    Utils.debug "stringify_map after stringify_keys, id '#{ id }'", 2
    if id =~ Utils.hex_24_chars_regex()  do
      if write do
        str = if str =~ @new_column_reg do
          str
        else
          str <> @new_column_field <> @new_value_field
        end
        del = String.replace @dele_button_field, "ID", id
        csrf_token = Phoenix.Controller.get_csrf_token()
        del = String.replace del, "CSRF_TOKEN", csrf_token
        save = String.replace @save_button_field, "ID", id
        map = MemoryDb.id_and_short_id id
        short_id = map["short_id"]
        edit = String.replace @edit_button_field, "ID", short_id
        str = str <> "<span style='display: inline-block;'>" <> save <> edit <> del <> "</span>" <> "<br/>\n"
        str

      else
        map = MemoryDb.id_and_short_id id
        short_id = map["short_id"]
        edit = if String.contains?( str, "</textarea>" ) do
                 String.replace @more_button_field, "ID", short_id
               else
                 ""
               end
        str = str <> "<div>" <> edit <> "</div><br/>\n"
        str
      end
    else
      Utils.debug "\n!!! stringify_map, id is `#{id}`!, str is #{Utils.sample str}  \n", 2
      "<div>Error: `#{safe id}` is not a valid hex id</div>"
    end
  end

# What I really want to do is get rid of all the HTML except the contents of the value fields in
# the inputs classification and name, plus any 'new columns', and the value field in hidden textarea 'page'
  def get_values( html, reg ) do
    one_line = String.replace html, "\n", " "
    one_line = String.replace one_line, @button_regex, ""
    one_line = String.replace one_line, @style_regex, ""
    values = Regex.scan reg, one_line
    values = List.flatten values
    str = Enum.join values
    str = String.replace str, "value=", ""
    str = String.replace str, "''", " "
    str = String.replace str, "\"\"", " "
    str
  end

  def select_articles( articles, s, c, write ) do
    Utils.debug "HtmlUtils.select_articles write #{write}, length articles #{ length articles}", 2
    case articles do
      [] -> []
      [hd | tl] ->
        id = elem( hd, 0 ) # These tuples should really all be turned into maps & the second element already has "_id"
        map = elem( hd, 1) # { "04672a6ac897f3fc88e1cf80", %{"classification" => "car", "page" => "<p>Mini</p>"... } }
        Utils.debug "select_articles just before calling stringify_map", 2
        article = stringify_map id, map, write
        Utils.debug "\nselect_articles write #{write}, id #{id}, name, '#{map["name"]}', stringified '#{article}'", 2
        cond do
          Utils.notmt? c ->     # <id="classification" name="classification" type="text" value="car">
            Utils.debug "\nselect_articles: c is #{c}"
            single_quotes_class_regex = ~r/classification.+name.+value='#{ c }'/
            double_quotes_class_regex = ~r/classification.+name.+value="#{ c }"/
            if article =~ single_quotes_class_regex || article =~ double_quotes_class_regex do
              [ { id, article } ] ++ select_articles( tl, s, c, write)
            else
              select_articles tl, s, c, write
            end
          true ->               # Sometimes it's value='value', sometimes it's value="value" (double quotes)
            s = if nil == s, do: "", else: String.downcase s
            singlequotes = get_values( article, @single_quotes_regex )
            doublequotes = get_values( article, @double_quotes_regex )
            eitherquotes = String.downcase( singlequotes ) <> String.downcase( doublequotes )
            Utils.debug "\nselect_articles s is #{s}, eitherquotes is #{eitherquotes}, eitherquotes contans s? #{String.contains?( eitherquotes, s ) }", 2
            if String.contains?( eitherquotes, s ) do
              [ { id, article } ] ++ select_articles( tl, s, c, write)
            else
              select_articles tl, s, c, write
            end
        end
    end
  end

  def contains_href_or_img?( text ) do
    down = String.downcase text
    String.contains?( down, "href=" ) || String.contains?( down, "href =" ) || (String.contains?(down, "<img") && (String.contains?(down, "src=") || String.contains?(down, "src =")))
  end

  def linkables?( text ) do
    if contains_href_or_img? text do
      []
    else
      no_nbsps = String.replace text, "&nbsp;", " "
# Regex.scan ~r/[^\s]+\.[0-9A-Za-z\/\?&=-]+/, " hello foo.com bye bar.co.uk " -> [ ["foo.com"], ["bar.co.uk"] ]
      list = Regex.scan @url_line_regex, no_nbsps
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
    stripped = if String.ends_with?( stripped, ["\"", "'", "."] ) do
                 String.slice( stripped, 0..-2 )
               else
                 stripped
               end
    strip_tags stripped
  end

# Arguments should be like [" hello ", " bye ", " "],
# ["<a href='#{ http://foo.com }'>foo.com</a>", "<a href='#{ http://bar.com }'>bar.com</a>"]
  def join_two_lists( one, two ) do
    case one do
      [] -> ""
      [hd1 | tl1] ->
         case two do
            [] ->
              hd1 <> ""  <> join_two_lists tl1, []
            [hd2 | tl2] ->
              hd1 <> hd2 <> join_two_lists tl1, tl2
         end
    end
  end

  def replace_link( str, link ) do
    str = if (link =~ @image_regex) && ! (String.contains? link, "/") do
            replaceable = "<img src='/images/#{ link }' style='display: block; margin-left: auto; margin-right: auto; width: 50%;'>"
            String.replace str, link, replaceable
          else
            if link =~ @proto_regex do
              replaceable = "<a target='_blank' href='#{ link }'>#{ link }</a>"
              String.replace str, link, replaceable
            else
              replaceable = "<a target='_blank' href='http://#{ link }'>#{ link }</a>"
              String.replace str, link, replaceable
            end
          end
    str
  end

  def in?( list, str ) do
    case list do
      [] -> false
      [hd | tl] ->
        if String.contains? str, hd do
          true
        else
          in? tl, str
        end
    end
  end

  def replace_links( strs, linkables ) do
    case strs do
      [] -> []
      [ hd | tl ] ->
        if in? linkables, hd do
          stripped = strip_extraneous_quotes_and_tags hd
          re = replace_link( hd, stripped )
          [ re ] ++ replace_links( tl, linkables )
        else
          [ hd ] ++ replace_links( tl, linkables )
        end
    end
  end

  def replace_linkables( line, linkables ) do
    strs = String.split line, @space_regex
    list = replace_links strs, linkables
    linked = Enum.join list, " "
    Utils.debug "HtmlUtils.replace_linkables/2 line '#{line}' returns '#{linked}'\n", 2
    linked
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

  def urlify( str ) do
    down = String.downcase str
    if String.starts_with?( down, "http") do
      "<a target='_blank' href='#{ str }'>#{ str }</a>"
    else
      if String.starts_with?( down, "<a ") do
        str
      else
        "<a target='_blank' href='http://#{ str }'>#{ str }</a>"
      end
    end
  end

  def auto_url!( html ) do
    str = if nil == html do
      ""
    else
    #  <a href="CCPFq"> - need to change this to /read
      str = String.replace html, "/write/edit", "/read/edit"
      str = String.replace str, "&ldquo;", "“"
      str = String.replace str, "&rdquo;", "”"
      str = String.replace str, "&amp;", "&"
      lines = String.split str, "\n"
      list = Enum.map(lines, fn(line) -> apply_regex( line, &apply_regexes/1 ) end)
      Enum.join list, "\n"
    end
    str
  end

  def trim_vals( map ) do
    list = Map.to_list map
    new_list = Enum.map( list, fn(a) -> {String.trim(elem(a, 0)), String.trim(elem(a, 1))} end )
    new_map = Enum.into( new_list, %{} )
    new_map
  end

# %{"c" => "online article", "s" => "_", "p" => "2"}
  def find( conn, params ) do
    Utils.debug "find()"
    args = trim_vals params
    s = args[ "s" ]
# Using underscore is a hack because router thinks find//car is find/car, so it's find/_/car - see index.html Javascript
    s = if "_" == s, do: "", else: s
    c = args[ "c" ]
    c = if "_" == c, do: "", else: c
    p = args[ "p" ]
    Utils.debug "HtmlUtils.find() - p is '#{p}'"
    p = if ! p, do: "1", else: p

    conn = if Utils.notmt? s do
      Utils.debug "find() - parameter s #{s}"
      conn = assign( conn, :s, s )
      assign( conn, :c, "" )
    else
      Utils.debug "find() - no parameter s"
      conn = assign( conn, :s, "" )
      if Utils.notmt? c do
        Utils.debug "find() - parameter c #{c}"
        assign( conn, :c, c )
      else
        assign( conn, :c, "" )
      end
    end
    conn = assign( conn, :a, args[ "a" ] )
    conn = assign( conn, :p, p )
    Utils.debug "HtmlUtils.find() - p is #{p}"
    render conn, "find.html", layout: false
  end

  def find_id( keys, map, reg ) do
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

  def display_page( html ) do
    if nil == html do
      ""
    else
      page = String.replace( html, "<html", "<div" )
      page = String.replace( page, "</html", "</div" )
      page = String.replace( page, "<body", "<div" )
      page = String.replace( page, "</body", "</div" )
      page = String.replace( page, "<head", "<div" )
      page = String.replace( page, "</head", "</div" )
      page = String.replace( page, "<HTML", "<div" )
      page = String.replace( page, "</HTML", "</div" )
      page = String.replace( page, "<BODY", "<div" )
      page = String.replace( page, "</BODY", "</div" )
      page = String.replace( page, "<HEAD", "<div" )
      page = String.replace( page, "</HEAD", "</div" )
      page = String.replace( page, "<?xml", "<div" )
      page = String.replace( page, "<!DOCTYPE html", "<div" )
      page = String.replace( page, "<!DOCTYPE", "<div" )
      page
    end
  end

  def summary( article ) do
    category = article[ "classification" ]
    name = article[ "name" ]
    author = article[ "author" ]
    author = if nil == author, do: "", else: "<br/>\n<b>" <> author <> "</b>"
    url = article[ "url" ]
    url = if nil == url, do: "", else: "<br/>\n" <> urlify url
    arc = article[ "archive url" ]
    arc = if nil == arc, do: "<br/>\n" , else: "<br/>\n" <> urlify( arc ) <> "<br/>\n"
    "<b>" <> category <> "</b>: " <> name <> " " <> author <> url <> arc
  end

  def show_classifications( url ) do
    list = if "/" == url, do: MemoryDb.read_articles( ), else: MemoryDb.write_articles()
    list = list |> classifications() |> MapSet.to_list()
    home = if "/" == url, do: "", else: "<a href='/'>HOME</a>&nbsp;&nbsp;&nbsp;" # read view doesn't need HOME 'cos HOME is the same as ALL, but in write view, they are different
    home <> "<b>Categories</b> " <> htmlify_classifications( list, url )
  end

  def classifications( list ) do # { "04672a6ac897f3fc88e1cf80", %{"classification" => "car"... }}
    Utils.debug "classifications #{Utils.what? list}"
    values = Enum.flat_map( list, fn(tuple) -> [ elem( tuple, 1 )[ "classification" ] ] end )
    MapSet.new values
  end

  def htmlify_classifications( list, url ) do
    case list do
      [] -> "&nbsp;&nbsp;<u><a href='#{ url }'>ALL</a></u>"
      [ hd | tl ] -> # Note advanced CSS style
         val = htmlify! hd
         "&nbsp;&nbsp;<u><a href='#{ url }?c=#{ val }'>#{ val }</a></u>" <> htmlify_classifications( tl, url )
    end
  end

  def mt?( s_or_c ) do # s is the search string, c is classification, when user clicked on a Category link at the top of the index page
    # See Javascript on index pages to see why s or c could be an underscore - it's so the find url can be /_/_/ etc. to avoid /// which doesn't get interpreted correctly
    nil == s_or_c || "" == s_or_c || " " == s_or_c || "_" == s_or_c
  end

  def page_url( url, num ) do
    "<b><u><a href='#{ url }?p=#{ num }'>#{ num }</a></u></b>&nbsp;&nbsp;"
  end

  def page_urls( url, num ) do
    if num < 1 do
      ""
    else
      page_urls( url, num - 1 ) <> page_url( url, num )
    end
  end

  def show_pages( url ) do
    num_pages = MemoryDb.number_of_pages( url )
    if num_pages < 2 do
      ""
    else
      "Pages &nbsp;" <> page_urls( url, num_pages )
    end
  end
end
