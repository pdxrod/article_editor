defmodule ArticleTest do
  use SimpleMongoAppWeb.ConnCase
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.Base58
  alias SimpleMongoApp.MemoryDb

  @page """
  <html><head></head>
  <body>
  <table style="border-color: #ff0000; border-width: 0px;" border="0" cellspacing="4" cellpadding="1" frame="above">
    <tbody>
    <tr>
    <td></td>
    </tr>
    <tr>
    <td>table</td>
    </tr>
    </tbody>
  </table>

  some text fredbloggs.co.th some more text
  https://jimbloggs.co.uk
   Hello this is "http://joebloggs.co.nz" a web page
     'http://janebloggs.com'
  <a href="http://sandrabloggs.com.au">sandra bloggs</a>
  Sara's website in a new tab: <a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>
  <p>tarquinbloggs.net</p>
  HTTP://CAPITAL-LETTERS.COM
  a sentence.
  <p>another sentence.</p>
  <p>some html text</p>
  https://jonathanbloggs.co.uk/an/article
  </body>
  </html>
  """

  @images """
  Hello the_image.jpg
    the_image.png Goodbye
      the_image.jpeg
        http://foo.com/the_image.jpeg
          bar.co.uk/the_image.jpeg
            <img src="/images/the_other_image.png">
            <img src='/images/the_other_other_image.png'>
              <img src = '/images/the_other_other_other_image.png'>
  """

  @html """
    The original,&nbsp;&nbsp;www.duke.edu/web/africanameric/listening.pdf, redirects
    The original,&nbsp;&nbsp;http://www.duke.edu/web/africanameric/listening.pdf, redirects
    <a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>
    some text fredbloggs.co.th some more text
    https://jimbloggs.co.uk
    http://foo.bar.com?foo=bar&baz=
    this is an ampersand &amp; hello
    This is a book https://www.amazon.com/Difficult-With-Dashes-ebook/dp/B001FA0SPG.
  Johnson, DC
  Washington, D.C.
  DC. Comics
  D.C is not a URL
    foobarbaz.com/write/edit/f0ffe3c2b807174b1b6decaf
<a target='_blank' href="../write/edit/decaf3c2b807174b1b6df0ff">../write/edit/decaf3c2b807174b1b6df0ff</a>
   www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police/
   https://www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police
   “James Madison”.
   &ldquo;George Washington&rdquo;.
  """

  describe "articles" do

    test "typeof" do
      assert "binary" == Utils.typeof( "Hello" )
      assert "list" == Utils.typeof( 'Hello' )
      assert "list" == Utils.typeof( [:a, :b] )
      assert "atom" == Utils.typeof( :foo )
      assert "map" == Utils.typeof( %{} )
      assert "map" == Utils.typeof( %{foo: :bar} )
      assert "tuple" == Utils.typeof( {:foo, "Hello"} )
    end

    test "each auto-urling function separately" do
      assert "foo.com" = HtmlUtils.strip_tags "<p>foo.com</p>"
      assert "foo.com" = HtmlUtils.strip_tags "<EM>foo.com</EM>"
      assert "http://foo.com" = HtmlUtils.strip_tags "<B><u>http://foo.com</u></b>"
      assert true == HtmlUtils.contains_href_or_img?  "<a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
      assert true == HtmlUtils.contains_href_or_img? "<a href = 'http://sarabloggs.biz'>sara bloggs</a>"
      assert true == HtmlUtils.contains_href_or_img? "<A HREF=\"http://sarabloggs.biz\">sara bloggs</A>"
      assert false == HtmlUtils.contains_href_or_img? "There is an html attribute called href"
      assert [] = HtmlUtils.linkables? "some text"
      assert [] = HtmlUtils.linkables? "some text <a target='_blank' href=\"http://fredbloggs.co.th\">fredbloggs.co.th</a> some more text"
      assert "http://foo.com" == HtmlUtils.strip_extraneous_quotes_and_tags "'http://foo.com'"
      assert "http://foo.com" == HtmlUtils.strip_extraneous_quotes_and_tags "\"http://foo.com\""
      assert "http://foo.com" == HtmlUtils.strip_extraneous_quotes_and_tags "http://foo.com"
      assert "http://foo.com" == HtmlUtils.strip_extraneous_quotes_and_tags "<p>http://foo.com</p>"
      assert "foo.com" == HtmlUtils.strip_extraneous_quotes_and_tags  "<p>foo.com</p>"

      one = [" hello ", " bye ", " "]
      two = [            "<a target='_blank' href='http://foo.com'>foo.com</a>",  "<a target='_blank' href='https://bar.co.uk'>https://bar.co.uk</a>"]
      two_lists = " hello <a target='_blank' href='http://foo.com'>foo.com</a> bye <a target='_blank' href='https://bar.co.uk'>https://bar.co.uk</a> "
      assert two_lists == HtmlUtils.join_two_lists one, two

      hello_goodbye = " hello foo.com bye bar.co.uk "
      assert ["foo.com", "bar.co.uk"] == HtmlUtils.linkables? hello_goodbye
      linked = HtmlUtils.replace_linkables hello_goodbye, ["foo.com", "bar.co.uk"]
# This is what the code does, when it's wrong:
      assert linked != " hello <a target='_blank' href='http://foo.com'>foo.com</a> bye bar.co.uk  hello foo.com bye <a target='_blank' href='http://bar.co.uk'>bar.co.uk</a> "
# This is what it should be:
      assert linked == " hello <a target='_blank' href='http://foo.com'>foo.com</a> bye <a target='_blank' href='http://bar.co.uk'>bar.co.uk</a> "

      same_link_twice = " hello foo.com bye foo.com "
      assert ["foo.com", "foo.com"]== HtmlUtils.linkables? same_link_twice
      linked = HtmlUtils.replace_linkables same_link_twice, ["foo.com", "foo.com"]
      assert linked == " hello <a target='_blank' href='http://foo.com'>foo.com</a> bye <a target='_blank' href='http://foo.com'>foo.com</a> "
    end

    test "auto=urling images" do
      urled = HtmlUtils.auto_url! @images
      assert String.contains? urled, "<img src='/images/the_image.jpg' style='display: block; margin-left: auto; margin-right: auto; width: 50%;'>"
      assert String.contains? urled, "<img src='/images/the_image.png' style='display: block; margin-left: auto; margin-right: auto; width: 50%;'>"
      assert String.contains? urled, "<img src='/images/the_image.jpeg' style='display: block; margin-left: auto; margin-right: auto; width: 50%;'>"
      assert String.contains? urled, "<a target='_blank' href='http://foo.com/the_image.jpeg'>http://foo.com/the_image.jpeg</a>"
      assert String.contains? urled, "<a target='_blank' href='http://bar.co.uk/the_image.jpeg'>bar.co.uk/the_image.jpeg</a>"
      assert String.contains? urled, "<img src=\"/images/the_other_image.png\">"
      assert String.contains? urled, "<img src='/images/the_other_other_image.png'>"
      assert String.contains? urled, "<img src = '/images/the_other_other_other_image.png'>"
    end

    test "auto-urling html" do
      assert "" == HtmlUtils.auto_url! nil
      assert "" == HtmlUtils.auto_url! ""
      assert " " == HtmlUtils.auto_url! " "
      urled = HtmlUtils.auto_url! @html
      assert String.contains? @html, "“James Madison”."
      assert String.contains? @html, "&ldquo;George Washington&rdquo;."
      assert String.contains? @html, "Johnson, DC"
      assert String.contains? @html, "Washington, D.C."
      assert String.contains? @html, "DC. Comics"
      assert String.contains? @html, "D.C is not a URL"
      assert String.contains? urled, "“James Madison”."
      assert String.contains? urled, "“George Washington”."
      assert String.contains? urled, "Johnson, DC"
      assert String.contains? urled, "Washington, D.C."
      assert String.contains? urled, "DC. Comics"
      assert String.contains? urled, "D.C is not a URL"
      assert String.contains? urled, "foobarbaz.com/read/edit/f0ffe3c2b807174b1b6decaf"
      assert String.contains? urled, "<a target='_blank' href=\"../read/edit/decaf3c2b807174b1b6df0ff\">../read/edit/decaf3c2b807174b1b6df0ff</a>"
      assert ! String.contains? urled, "this is an ampersand &amp; hello"
      assert String.contains? urled, "this is an ampersand & hello"
      assert String.contains? urled, "The original,  <a target='_blank' href='http://www.duke.edu/web/africanameric/listening.pdf,'>http://www.duke.edu/web/africanameric/listening.pdf,</a> redirects"
      assert String.contains? urled, "The original,  <a target='_blank' href='http://www.duke.edu/web/africanameric/listening.pdf,'>www.duke.edu/web/africanameric/listening.pdf,</a> redirects"
      assert String.contains? urled, "<a target='_blank' href='https://www.amazon.com/Difficult-With-Dashes-ebook/dp/B001FA0SPG'>https://www.amazon.com/Difficult-With-Dashes-ebook/dp/B001FA0SPG</a>."
      assert String.contains? urled, "<a target='_blank' href='http://foo.bar.com?foo=bar&baz='>http://foo.bar.com?foo=bar&baz=</a>"
      assert String.contains? urled, "some text <a target='_blank' href='http://fredbloggs.co.th'>fredbloggs.co.th</a> some more text"
      assert String.contains? urled, "<a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
      assert String.contains? urled, "<a target='_blank' href='https://jimbloggs.co.uk'>https://jimbloggs.co.uk</a>"
      assert String.contains? urled, "<a target='_blank' href='http://www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police/'>www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police/</a>"
      assert String.contains? urled, "<a target='_blank' href='https://www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police'>https://www.civitas.org.uk/reports_articles/racist-murder-and-pressure-group-politics-the-macpherson-report-and-the-police</a>"
    end

    test "auto-urling page" do
      urled = HtmlUtils.auto_url! @page
      assert String.contains? urled, "a sentence."
      assert ! String.contains? urled, "href='http://sentence.'>sentence."
      assert ! String.contains? urled, "href=\"http://sentence.\">sentence."
      assert String.contains? urled, "<p>some html text</p>"
      assert String.contains? urled, "<a target='_blank' href='https://jonathanbloggs.co.uk/an/article'>https://jonathanbloggs.co.uk/an/article</a>"
      assert String.contains? urled, "<a target='_blank' href='HTTP://CAPITAL-LETTERS.COM'>HTTP://CAPITAL-LETTERS.COM</a>"
      assert String.contains? urled, "<a target='_blank' href='http://tarquinbloggs.net'>tarquinbloggs.net</a>"
      assert String.contains? urled, "some text <a target='_blank' href='http://fredbloggs.co.th'>fredbloggs.co.th</a> some more text"
      assert String.contains? urled, "<a target='_blank' href='https://jimbloggs.co.uk'>https://jimbloggs.co.uk</a>"
      assert String.contains? urled, "<a target='_blank' href='http://joebloggs.co.nz'>http://joebloggs.co.nz</a>"
      assert String.contains? urled, "<a target='_blank' href='http://janebloggs.com'>http://janebloggs.com</a>"
      assert String.contains? urled, "<a href=\"http://sandrabloggs.com.au\">sandra bloggs</a>"
      assert String.contains? urled, "Sara's website in a new tab: <a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
    end

@summary_max """
<b>online article</b>: It’s time to get real about freedom of speech <br/>
<b>Brendan O'Neill</b><br/>
<a target='_blank' href='https://guardian.com/uk/2021/02/19/freedom-of-speech/'>https://guardian.com/uk/2021/02/19/freedom-of-speech/</a><br/>
<a target='_blank' href='https://archive.is/MZ4Rb'>https://archive.is/MZ4Rb</a><br/>
"""
@summary_min """
<b>newspaper article</b>: It’s not time to get real about freedom of speech <br/>
<b>Owen Jones</b><br/>
"""

    test "summary" do
      article = %{"author" => "Brendan O'Neill", "archive url" => "https://archive.is/MZ4Rb", "url" => "https://guardian.com/uk/2021/02/19/freedom-of-speech/",
                  "_id" => "f00baa", "classification" => "online article", "name" => "It’s time to get real about freedom of speech", "short_id" => "1NPyz" }
      summary = HtmlUtils.summary article
      assert @summary_max == summary
      article = %{"author" => "Owen Jones", "_id" => "00f0ff", "classification" => "newspaper article",
                  "name" => "It’s not time to get real about freedom of speech", "short_id" => "Pyz1N" }
      summary = HtmlUtils.summary article
      assert @summary_min == summary
    end

    test "sidebar" do
      assert nil == MemoryDb.id_from_url nil
      assert nil == MemoryDb.id_from_url "Hello world!"

      id1 = String.slice( RandomBytes.base16, 0..23 )
      map = MemoryDb.id_and_short_id id1
      sid = map["short_id"]
      one = %{"classification" => "foo", "name" => "bar", "url" => "http://foo.com", "_id" => id1, "short_id" => sid}
      id2 = String.slice( RandomBytes.base16, 0..23 )
      map = MemoryDb.id_and_short_id id2
      url = "http://localhost:4000/read/edit/#{ id1 }"
      id = MemoryDb.id_from_url url
      assert id == id1

      two = %{"classification" => "sidebar", "page" => "<p>This is the sidebar</p>", "url" => url, "name" => "two", "_id" => id2, "short_id" => map["short_id"]}
      MemoryDb.put id1, one
      MemoryDb.put id2, two
      articles = MemoryDb.articles()
      len = length articles
      assert 1 < len

      main = MemoryDb.peek id1
      sidebar = HtmlUtils.sidebar main
      assert "<p>This is the sidebar</p><br/>\n" == sidebar
      main = MemoryDb.peek sid
      sidebar = HtmlUtils.sidebar main
      assert "<p>This is the sidebar</p><br/>\n" == sidebar

      url = "http://foobarbaz.com/read/edit/#{ sid }"
      id = MemoryDb.id_from_url url
      assert id == sid
      now = DateTime.utc_now()
      later = DateTime.add( now, 60 )
      two = %{"datetime" => now, "classification" => "sidebar", "page" => "<p>This is the first sidebar</p>", "url" => url, "name" => "two", "_id" => id2, "short_id" => map["short_id"]}
      hex = String.slice( RandomBytes.base16, 0..23 )
      short_id = Base58.hex_id_to_short_id hex
      three = %{"datetime" => later, "classification" => "sidebar", "page" => "<p>This is the second sidebar</p>", "url" => url, "name" => "three", "_id" => hex, "short_id" => short_id}

      MemoryDb.put id2, two
      MemoryDb.put hex, three
      articles = MemoryDb.articles()
      assert len + 1 == length articles

      main = MemoryDb.peek id1
      sidebar = HtmlUtils.sidebar main
      assert "<p>This is the second sidebar</p><br/>\n<p>This is the first sidebar</p><br/>\n" == sidebar
      main = MemoryDb.peek sid
      sidebar = HtmlUtils.sidebar main
      assert "<p>This is the second sidebar</p><br/>\n<p>This is the first sidebar</p><br/>\n" == sidebar

      other = MemoryDb.peek id2
      sidebar = HtmlUtils.sidebar other
      assert "" == sidebar
    end

    test "pages" do
      list = ["a", "b", "c", "d", "e"]
      pages = [1, 2]
      selection = Utils.select list, pages
      assert ["a", "b"] == selection
      pages = [2, 3, 4]
      selection = Utils.select list, pages
      assert ["b", "c", "d"] == selection
      range = 1..1
      selection = Utils.selection list, range
      assert ["a"] == selection
      range = 5..5
      selection = Utils.selection list, range
      assert ["e"] == selection
      range = 1..5
      selection = Utils.selection list, range
      assert ["a", "b", "c", "d", "e"] == selection
      range = 2..4
      selection = Utils.selection list, range
      assert ["b", "c", "d"] == selection
      list = []
      selection = Utils.selection list, range
      assert [] == selection
    end

    test "time" do # See login_utils
      now = DateTime.utc_now()
      from_now_24_hours = DateTime.add now, 24 * 60 * 60
      minutes_ago_31 = DateTime.add now, -60 * 31
      minutes_ago_29 = DateTime.add now, -60 * 29
      assert -86400 == DateTime.diff now, from_now_24_hours
      assert   1860 == DateTime.diff now, minutes_ago_31
      assert   1740 == DateTime.diff now, minutes_ago_29
      assert DateTime.diff( now, from_now_24_hours ) < 0
      assert DateTime.diff( now, minutes_ago_31 )    > 30 * 60
      assert DateTime.diff( now, minutes_ago_29 )    < 30 * 60
    end

    test "id regexes" do
      assert    "11142c6b9498b973c51556ed" =~ Utils.hex_24_chars_regex
      assert ! ("911142c6b9498b973c51556ed" =~ Utils.hex_24_chars_regex)
      assert ! ("911142c6b9" =~ Utils.hex_24_chars_regex)
      assert ! ("g1142c6b9498b973c51556ed" =~ Utils.hex_24_chars_regex)

      assert    "g1142c" =~ Utils.base_58_6_chars_regex
      assert ! ("g1142cd" =~ Utils.base_58_6_chars_regex)
# [1-9a-km-zA-HJ-NP-Z]
      assert    "LH123i" =~ Utils.base_58_6_chars_regex
      assert ! ("LLH123i" =~ Utils.base_58_6_chars_regex)
      assert ! ("H123i" =~ Utils.base_58_6_chars_regex)
      assert ! ("LH023i" =~ Utils.base_58_6_chars_regex)
      assert ! ("lH123i" =~ Utils.base_58_6_chars_regex)
      assert ! ("LI123i" =~ Utils.base_58_6_chars_regex)
# Now test base 64 regex
      assert    "LH123=" =~ Utils.base_64_6_chars_regex
      assert    "LH123i" =~ Utils.base_64_6_chars_regex
      assert ! ("LLH123i" =~ Utils.base_64_6_chars_regex)
      assert ! ("H123i" =~ Utils.base_64_6_chars_regex)
      assert ! ("LLH12!" =~ Utils.base_64_6_chars_regex)

      assert    "L123i" =~ Utils.base_64_5_chars_regex
      assert ! ("LH123i" =~ Utils.base_64_5_chars_regex)
      assert ! ("H23i" =~ Utils.base_64_5_chars_regex)
      assert ! ("LH12!" =~ Utils.base_64_5_chars_regex)

      assert    "LH231" =~ Utils.base_58_5_chars_regex
      assert    "L123i" =~ Utils.base_58_5_chars_regex
      assert ! ("LH23=" =~ Utils.base_58_5_chars_regex)
      assert ! ("LH230" =~ Utils.base_58_5_chars_regex)
      assert ! ("LH23l" =~ Utils.base_58_5_chars_regex)
      assert ! ("LH23O" =~ Utils.base_58_5_chars_regex)
      assert ! ("LH23I" =~ Utils.base_58_5_chars_regex)
      assert ! ("LH123i" =~ Utils.base_58_5_chars_regex)
      assert ! ("H23i" =~ Utils.base_58_5_chars_regex)
    end

    defp map_of_hex_ids_to_short_ids( num ) do
      if num < 1 do
        %{}
      else
        hex = String.slice( RandomBytes.base16, 0..23 )
        short_64 = Base58.hex_id_to_short_id hex
        map = %{hex => short_64}
        Map.merge map, map_of_hex_ids_to_short_ids( num - 1 )
      end
   end

   test "uniqueness of short ids" do
      map = map_of_hex_ids_to_short_ids 500
      assert 500 == length( Map.keys map )
      keys = Enum.uniq( Map.keys map )
      vals = Enum.uniq( Map.values map )
      assert 500 == length keys
      assert 500 == length vals
    end

    test "validity of ids" do
      assert false == MemoryDb.valid_id? nil
      assert 24 == String.length         "000000000000000000000000"
      assert false == MemoryDb.valid_id? "000000000000000000000000"
      assert 5 == String.length          "zzzzz"
      assert false == MemoryDb.valid_id? "zzzzz"
      assert false == MemoryDb.valid_id? "0000000000000000000000009"
      assert false == MemoryDb.valid_id? "zzzzzA"
      assert false == MemoryDb.valid_id? "00000000000009"
      assert false == MemoryDb.valid_id? "z"

      id1 = String.slice( RandomBytes.base16, 0..23 )
      map = MemoryDb.id_and_short_id id1
      one = %{"classification" => "foo", "name" => "bar", "url" => "http://foo.com", "_id" => id1, "short_id" => map["short_id"]}
      id2 = String.slice( RandomBytes.base16, 0..23 )
      map = MemoryDb.id_and_short_id id2
      two = %{"classification" => "bar", "name" => "foo", "url" => "http://bar.co.uk", "_id" => id2, "short_id" => map["short_id"]}
      MemoryDb.put id1, one
      MemoryDb.put id2, two

      articles = MemoryDb.articles()
      assert 1 < length articles
      tuple = List.first articles
      first_article = elem( tuple, 1 )
      id = first_article["_id"]
      short_id = first_article["short_id"]
      assert true == MemoryDb.valid_id? id
      assert true == MemoryDb.valid_id? short_id
      tuple = List.last articles
      last_article = elem( tuple, 1 )
      assert last_article["_id"] != first_article["_id"]
      id = last_article["_id"]
      short_id = last_article["short_id"]
      assert true == MemoryDb.valid_id? id
      assert true == MemoryDb.valid_id? short_id
    end

    test "hex_id_to_short_id" do # It's not reversible, except by looking for the article by short_id, and finding its _id
      assert 24 == String.length                  "000000000000000000000000"
      assert "11111" == Base58.hex_id_to_short_id "000000000000000000000000"
      assert "4444j" == Base58.hex_id_to_short_id "ffffffffffffffffffffffff"
      assert "onYUN" == Base58.hex_id_to_short_id "decaf3c2b807174b1b6df0ff"
      assert "cU3Gy" == Base58.hex_id_to_short_id "18b93c9462cb978dbd5c0e78"
      assert "Tr1dv" == Base58.hex_id_to_short_id "25142d1764340bc661feab35"
      assert "E4rR6" == Base58.hex_id_to_short_id "f8f984bcd2beb07b2c8ff764"
    end

    test "base 58 functions" do
      assert 58 == length Base58.alphabet
      hex = "decaf3c2b807174b1b6df0ff"
      assert 24 == String.length hex
      chunks = Base58.split_hex_into_chunks hex
      assert 5 == length chunks
      assert 5 = String.length( List.first chunks )
      assert 4 = String.length( List.last chunks )

      zero = "00000"
      char = Base58.make_single_base_58_char(  zero )
      assert "1" == char
      fffff = "fffff"
      char = Base58.make_single_base_58_char(  fffff )
      assert "4" == char
      ffff = "ffff"
      char = Base58.make_single_base_58_char(  ffff )
      assert "j" == char
    end

    test "chunks" do
      str = "¡Hello World!"
      assert 13 == String.length str
      chunks = Utils.chunk 13, str
      assert 1 == length chunks
      assert List.first( chunks ) == str
      chunks = Utils.chunk 14, str
      assert 1 == length chunks
      assert List.first( chunks ) == str
      chunks = Utils.chunk 12, str
      assert 2 == length chunks
      assert "¡Hello World" == List.first chunks
      assert "!" == List.last chunks

      {:ok, small} = File.read "small.html"
      assert 1390 == String.length small
      chunks = Utils.chunk( 1700, small )
      assert 1 == length chunks
      chunk = List.first chunks
      assert chunk == small

      {:ok, big} = File.read "big.html"
      assert 55604 = String.length big
      chunks = Utils.chunk( 1700, big )
      assert 33 == length chunks      #  55604 / 1700 == 32.70823529411765
      chunk = List.first chunks
      assert 1700 == String.length chunk
      big_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
      len = String.length big_header
      beginning = String.slice chunk, 0 .. len-1
      assert big_header == beginning
      chunk = List.last chunks
      len = String.length chunk
      assert 1700 > len
      big_ender = "</body></html>\n"
      ending = String.slice chunk, len-15 .. len-1
      assert big_ender == ending
    end

  end
end
