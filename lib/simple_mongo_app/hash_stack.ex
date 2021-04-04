defmodule SimpleMongoApp.HashStack do
  alias SimpleMongoApp.Utils

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__ )
  end

  def put( id, hash ) do
    Utils.debug "HashStack put '#{id}' '#{hash}'", 2
    Agent.update(__MODULE__, &Map.put( &1, id, hash ))
  end

  def peek( id ) do
    article = Agent.get(__MODULE__, &Map.get( &1, id ))
    Utils.debug "HashStack peek '#{id}' #{Utils.debug_ids article}", 2
    article
  end

  def size do
    keys = Agent.get(__MODULE__, &Map.keys( &1 ))
    length keys
  end

end
