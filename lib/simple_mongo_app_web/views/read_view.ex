defmodule SimpleMongoAppWeb.ReadView do
  use SimpleMongoAppWeb, :view
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.HtmlUtils
  alias SimpleMongoApp.MemoryDb

  def show_classifications do
    HtmlUtils.show_classifications "/"
  end

  def show_pages do
    HtmlUtils.show_pages "/"
  end

  def show_articles( s, c, p ) do
    Utils.debug "read show_articles s '#{s}' c '#{c}' p '#{p}'", 3
    try do
      HtmlUtils.select_articles MemoryDb.articles( ), s, c, false, p
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
