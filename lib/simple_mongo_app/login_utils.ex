defmodule SimpleMongoApp.LoginUtils do
  alias SimpleMongoApp.Utils
  alias SimpleMongoApp.MemoryDb

  def logged_in_and_not_timed_out?( conn ) do
    Utils.debug "logged_in_and_not_timed_out?", 2
    logging_in_from_a_blocked_ip_over_24_hours_later?( conn )
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    last_login_time = MemoryDb.peek( ip )
    result = if last_login_time do
        if more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours?( conn ) do
          Utils.debug "more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours? is true", 2
          false
        else
          Utils.debug "more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours? is false", 2
          failed = last_login_time[ "unsuccessful_logins" ]
          then = last_login_time["datetime"]
          now = DateTime.utc_now()
          diff = DateTime.diff( now, then )
          less_than_55_mins = diff < 55 * 60
          Utils.debug "unsuccessful_logins is #{failed} and diff now #{now} and last login time #{then} is #{diff} - less than 55 mins? #{less_than_55_mins}", 2
          result = (0 == failed) && (less_than_55_mins)
          result
        end
      else
        false
      end
    Utils.debug "logged_in_and_not_timed_out? result #{result}", 2
    result
  end

  defp save_login_time_for_this_ip!( ip, new_map ) do
    Utils.debug "save_login_time_for_this_ip!! puting ip '#{ip}' #{Utils.debug_ids new_map} in MemoryDb", 2
    id_map = %{"_id" => ip}
    map = Map.merge id_map, new_map
    MemoryDb.put(ip, map )
    Utils.debug "save_login_time_for_this_ip!! ends", 2
  end

  def save_login_time!( conn ) do
    Utils.debug "save_login_time!", 2
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    map = %{"datetime" => DateTime.utc_now(), "unsuccessful_logins" => 0 }
    Utils.debug "save_login_time! calling save_login_time_for_this_ip! '#{ip}' #{Utils.debug_ids map}", 2
    save_login_time_for_this_ip!( ip, map )
  end

  def increment_unsuccessful_logins!( conn ) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    last_login_time = MemoryDb.peek( ip )
    if last_login_time do
      failed = last_login_time["unsuccessful_logins"]
      failed = if nil == failed, do: 1, else: failed + 1
      then = last_login_time["datetime"]
      now = DateTime.utc_now()
      datetime = if failed > 4, do: DateTime.add( now, 24 * 60 * 60 ), else: then
      failed = if failed > 4, do: 100, else: failed
      Utils.debug "\nincrement_unsuccessful_logins! unsuccessful logins: #{failed}"
      map = %{ "datetime" => datetime, "unsuccessful_logins" => failed }
      save_login_time_for_this_ip!( ip, map )
    else
      Utils.debug "creating new unsuccessful logins record"
      now = DateTime.utc_now()
      map = %{ "datetime" => now, "unsuccessful_logins" => 1 }
      save_login_time_for_this_ip!( ip, map )
    end
  end

  defp logging_in_from_a_blocked_ip_over_24_hours_later?( conn ) do
    Utils.debug "logging_in_from_a_blocked_ip_over_24_hours_later?"
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    last_login_time = MemoryDb.peek( ip )
    if last_login_time do
      failed = last_login_time["unsuccessful_logins"]
      then = last_login_time["datetime"]
      now = DateTime.utc_now()
      diff = DateTime.diff( now, then )
# This ip was blocked over 24 hours ago - delete the record, then you can log in from this ip
      if (100 == failed) && (diff > 60) do
        Utils.debug "deleting old blocked ip record - unsuccessful logins is #{failed} and diff is #{diff}"
        MemoryDb.delete_one( ip )
      end
    end
  end

  def logging_in?( args ) do
    name = args["_name"]
    password = args["_password"]
    Utils.notmt?( name ) || Utils.notmt?( password )
  end

  defp last_login_time_is_in_future?( last_login_time ) do
    now = DateTime.utc_now()
    then = last_login_time["datetime"]
    Utils.debug "last_login_time_is_in_future? - diff now, then is #{DateTime.diff( now, then )}"
    DateTime.diff( now, then ) < 0
  end

  def more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours?( conn ) do
    Utils.debug "more_than_4_unsuccessful_logins_from_this_ip_in_last_24_hours?"
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    last_login_time = MemoryDb.peek( ip )
    if last_login_time do
      failed = last_login_time["unsuccessful_logins"]
      Utils.debug "more_than_4_unsuccessful_logins? - unsuccessful logins is #{failed}, last_login_time_is_in_future? is #{ last_login_time_is_in_future?( last_login_time ) }"
      (100 == failed) && last_login_time_is_in_future?( last_login_time )
    else
      Utils.debug "more_than_4_unsuccessful_logins? - no login record"
      false
    end
  end

  def correct_username_and_password?( args ) do
    name = args["_name"]
    password = args["_password"]
    str = "name #{name} password #{password}"
    str == Utils.str()
  end

end
