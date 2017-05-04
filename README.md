# morechunks-server
Simple TCP server that provides chunks on request and allows clients to update them.

Install dependencies: `mix deps.get`

Run: `iex -S mix`

## Client example
Run `iex` and type/paste:
```elixir
# open a connection to the server
{:ok, sock} = :gen_tcp.connect {127,0,0,1}, 12312, [packet: 4]
# send a message (packet type of 1)
:gen_tcp.send sock, "\x01Hello server"
# send a fake chunk: p_type timestamp chunk_x chunk_z chunk_data
:gen_tcp.send sock, <<0::8, 1234::64, 98::32, 76::32, "this is a fake chunk">>
# be nice and close the connection
:gen_tcp.close sock
```
