defmodule SimpleMongoApp.Base58 do
# The angel said no l, and they didn't have 0 back then
  @alphabet "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
  @hexdigits "0123456789abcdef"

  def alphabet do
    a = String.split( @alphabet, "" )
    a = Enum.slice a, 1..-2 # Get rid of the empty strings which appear at each end
    a
  end

  def hexdigits do
    a = String.split( @hexdigits, "" )
    a = Enum.slice a, 1..-2 # Get rid of the empty strings which appear at each end
    a
  end

  def split_hex_into_chunks( hex ) do
    cond do
      "" == hex ->
        []
      5 == String.length( hex ) ->
        [ hex ]
      4 == String.length( hex ) ->
        [ hex ]
      true ->
        [ String.slice( hex, 0..4 ) ] ++ split_hex_into_chunks( String.slice( hex, 5..-1 ) )
    end
  end

  def make_single_base_58_char( hex_chunk ) do
    tup = Integer.parse( hex_chunk, 16 )
    num = elem tup, 0
    num = Integer.mod num, 57
    chr = Enum.at alphabet, num
    chr
  end

  def make_short_id( chunks ) do
    case chunks do
      [] -> ""
      [hd | tl] ->
        make_single_base_58_char( hd ) <> make_short_id( tl )
    end
  end

  def hex_id_to_short_id( hex_id ) do
    chunks = split_hex_into_chunks hex_id
    make_short_id chunks
  end

end
