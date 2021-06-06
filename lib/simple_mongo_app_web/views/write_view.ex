defmodule SimpleMongoAppWeb.WriteView do
  use SimpleMongoAppWeb, :view
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.MemoryDb

  defp empty_row do
    id = String.slice( RandomBytes.base16, 0..23 )
    map = %{ name: "", classification: "" }
    str = HtmlUtils.stringify_keys( Map.keys( map ), map, &HtmlUtils.write_htmlify_key_val/2, "" )
    save = String.replace HtmlUtils.save_button_field(), "ID", id
    label = "<div><b>New article</b></div><br/>\n"
    [ { id, label <> str <> save } ]
  end

  def show_classifications do
    HtmlUtils.show_classifications "/write"
  end

  def show_pages do
    HtmlUtils.show_pages "/write"
  end

  def show_articles( s, c, p ) do
    try do
      p = if HtmlUtils.mt?( s ) && HtmlUtils.mt?( c ), do: p, else: nil
      articles = MemoryDb.articles_for_page( p, false )
      empty_row() ++ HtmlUtils.select_articles articles, s, c, true
    rescue
      re in RuntimeError -> re
      [ { "decaf0ff", "Error: #{ re.message }" } ]
    end
  end

  def display_page( html ) do
    HtmlUtils.display_page html
  end

  def show_article( id ) do
    HtmlUtils.show_article id
  end

end
