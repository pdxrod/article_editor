defmodule SimpleMongoApp.BackgroundSaver do
  use GenServer
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.MemoryDb
  alias SimpleMongoApp.MongoDb
  alias SimpleMongoApp.HashStack

# https://stackoverflow.com/questions/32085258/how-can-i-schedule-code-to-run-every-few-hours-in-elixir-or-phoenix-framework

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    Utils.debug "BackgroundSaver init starting", 2
    schedule_work() # Schedule work to be performed at some point
    Utils.debug "BackgroundSaver init ending", 2
    {:ok, state}
  end

  def handle_info(:work, state) do
    Utils.debug "BackgroundSaver handle_info starting synchronize()", 2
    synchronize() # Do it
    Utils.debug "BackgroundSaver handle_info starting schedule_work()", 2
    schedule_work() # Reschedule once more
    Utils.debug "BackgroundSaver handle_info ending", 2
    {:noreply, state}
  end

  defp schedule_work() do
    Utils.debug "BackgroundSaver schedule_work", 2
    timings = Utils.timings()
    timing = elem( timings, 1 )
    Process.send_after(self(), :work, timing * 60 * 1_000)
  end

  defp synchronize do
    Utils.debug "BackgroundSaver synchronize starting", 2
    map = MemoryDb.all()
    list = Map.values(map) # The map's keys are like "f0ffdecaf", but the values are like %{"_id" => "f0ffdecaf", "name" => "foo", ...}
    Utils.debug "BackgroundSaver synchronize list #{Utils.debug_ids list}", 2
    ok = save_articles_in_mongo_db_which_have_changed_in_memory_db( list )
    Utils.debug "BackgroundSaver synchronize ending #{ok}", 2
  end

  defp save_articles_in_mongo_db_which_have_changed_in_memory_db( list ) do
    case list do
      [] -> :ok
      [head | tail] ->
        id = head[ "_id" ]
        Utils.debug "BackgroundSaver save_articles_in_mongo_db_which_have_changed_in_memory_db id '#{id}' #{Utils.debug_ids head}", 3
        if Utils.mt?(id), do: Utils.debug "ID IS MT IN THIS ARTICLE #{Utils.debug_ids head}", 3

        map = MemoryDb.id_and_short_id id
        hex = map["id"]
        save_in_mongo_and_update_hash_in_map_if_it_has_changed?( hex, head )

        Utils.debug "BackgroundSaver save_articles_in_mongo_db_which_have_changed_in_memory_db( tail )", 2
        save_articles_in_mongo_db_which_have_changed_in_memory_db( tail )
    end
  end

  defp save_in_mongo_and_update_hash_in_map_if_it_has_changed?( id, article ) do
    new_hash = hash_article article
    map = MemoryDb.id_and_short_id id
    id3 = map["id"]
    sid = map["short_id"]
    old_hash = HashStack.peek id3
    if old_hash != new_hash do
      if id3 =~ Utils.hex_24_chars_regex(), do: Utils.debug "\nBackgroundSaver save_in_mongo_and_update_hash_in_map_if_it_has_changed? SAVING id '#{id3}'", 3
      HashStack.put id3, new_hash
      id_map = %{"_id" => id3}
      sid_map = %{"short_id" => sid}
      article = Map.merge article, sid_map
      MongoDb.find_one_and_replace( id_map, article )
    else
      if id3 =~ Utils.hex_24_chars_regex(), do: Utils.debug "BackgroundSaver save_in_mongo_and_update_hash_in_map_if_it_has_changed? NOT SAVING id '#{id3}'", 3
    end
  end

  defp hash_article( article ) do
    str_list = Enum.map( article, fn(a) -> "#{ elem(a, 0) } #{ elem(a, 1) }" end )
    str = Enum.join str_list, " "
    hash = :crypto.hash(:md5, str) |> Base.encode16() |> String.downcase()
    hash
  end

end
