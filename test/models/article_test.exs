defmodule ArticleTest do
  use SimpleMongoAppWeb.ConnCase
  alias SimpleMongoApp.Utils

  @html """
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

  fredbloggs.co.th
  https://jimbloggs.co.uk
  "http://joebloggs.co.nz"
  'http://janebloggs.com'
  <a href="http://sandrabloggs.com.au">sandra bloggs</a>
  <a href='http://sarabloggs.biz'>sara bloggs</a>

  <p>some html text</p>
  <p>some more</p>
  <p>hello</p>
  <p><a href="http://google.com">goodbye</a></p>
  <p>&nbsp;</p>
    <ul>
    <li>this</li>
    <li>is</li>
    <li>a&nbsp;</li>
    <li>list</li>
    </ul>
  <p>&nbsp;</p>
  <table border="0" cellspacing="8" cellpadding="4" width="88" align="left">
    <tbody>
    <tr>
    <td></td>
    <td></td>
    </tr>
    <tr>
    <td></td>
    <td>table</td>
    </tr>
    </tbody>
  </table>
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

    test "auto-urling" do
      urled = Utils.auto_url! @html
      assert String.contains? urled, "<p>some html text</p>"
      assert String.contains? urled, "<a href=\"http://fredbloggs.co.th\">fredbloggs.co.th</a>"
      assert String.contains? urled, "<a href=\"https://jimbloggs.co.uk\">https://jimbloggs.co.uk</a>"
      assert String.contains? urled, "<a href=\"http://joebloggs.co.nz\">http://joebloggs.co.nz</a>"
      assert String.contains? urled, "<a href='http://janebloggs.com'>http://janebloggs.com</a>"
      assert String.contains? urled, "<a href=\"http://sandrabloggs.com.au\">sandra bloggs</a>"
      assert String.contains? urled, "<a href='http://sarabloggs.biz'>sara bloggs</a>"
    end

  end

end
