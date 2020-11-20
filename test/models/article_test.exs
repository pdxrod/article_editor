defmodule ArticleTest do
  use SimpleMongoAppWeb.ConnCase
  alias SimpleMongoApp.Utils

  @page """
  <html><head></head>
  <body>
  <table style="border-color: #ff0000; border-width: 0px;" border="0" cellspacing="4" cellpadding="1" frame="above">
    <tbody>
    <tr>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
    </tr>
    <tr>
    <td></td>
    <td></td>
    <td></td>
    <td></td>
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

  <p>some html text</p>
  <p>some more</p>
  <p>hello</p>
  <p>&nbsp;</p>
    <ul>
    <li>this</li>
    <li>is</li>
    <li>a&nbsp;</li>
    <li>list</li>
    </ul>
  <p>&nbsp;</p>
  </body>
  </html>
  """

  @html """
    <a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>
    some text fredbloggs.co.th some more text
    https://jimbloggs.co.uk
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
      assert true == Utils.contains_href?  "<a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
      assert true == Utils.contains_href? "<a href = 'http://sarabloggs.biz'>sara bloggs</a>"
      assert true == Utils.contains_href? "<A HREF=\"http://sarabloggs.biz\">sara bloggs</A>"
      assert false == Utils.contains_href? "There is an html attribute called href"
      assert [] = Utils.linkables? "some text"
      assert [] = Utils.linkables? "some text <a target='_blank' href=\"http://fredbloggs.co.th\">fredbloggs.co.th</a> some more text"
      assert ["foo.com", "bar.co.uk"]== Utils.linkables? " hello foo.com bye bar.co.uk "
      assert " hello <a target='_blank' href='http://foo.com'>foo.com</a> bye bar.co.uk  hello foo.com bye <a target='_blank' href='http://bar.co.uk'>bar.co.uk</a> " == Utils.replace_linkables " hello foo.com bye bar.co.uk ",  ["foo.com", "bar.co.uk"]
    end

    test "auto-urling html" do
      urled = Utils.auto_url! @html
      assert String.contains? urled, "some text <a target='_blank' href='http://fredbloggs.co.th'>fredbloggs.co.th</a> some more text"
      assert String.contains? urled, "<a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
      assert String.contains? urled, "<a target='_blank' href='https://jimbloggs.co.uk'>https://jimbloggs.co.uk</a>"
    end

    test "auto-urling page" do
      urled = Utils.auto_url! @page
      assert String.contains? urled, "<p>some html text</p>"
      assert String.contains? urled, "some text <a target='_blank' href=\"http://fredbloggs.co.th\">fredbloggs.co.th</a> some more text"
      assert String.contains? urled, "<a target='_blank' href=\"https://jimbloggs.co.uk\">https://jimbloggs.co.uk</a>"
      assert String.contains? urled, "<a target='_blank' href=\"http://joebloggs.co.nz\">http://joebloggs.co.nz</a>"
      assert String.contains? urled, "<a target='_blank' href='http://janebloggs.com'>http://janebloggs.com</a>"
      assert String.contains? urled, "<a target='_blank' href=\"http://sandrabloggs.com.au\">sandra bloggs</a>"
      assert String.contains? urled, "Sara's website in a new tab: <a target='_blank' href='http://sarabloggs.biz'>sara bloggs</a>"
    end



  end

end
