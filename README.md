# MoreChunks Server

File-backed chunk storage server that provides chunks on request and allows clients to update them.

**Looking for the [Client Mod](https://github.com/Gjum/morechunks-forge)?**

## Installation and Usage

- Install dependencies: `mix deps.get`
- Configure: edit `config/config.exs`
- Test run interactively: `iex -S mix`
- Run in production: `MIX_ENV=prod elixir -S mix run --no-halt`

## Client Example

Run `iex` and type/paste:

```elixir
# open a connection to the server
{:ok, sock} = :gen_tcp.connect {127,0,0,1}, 44444, [packet: 4]
# send a message (packet type 1)
:gen_tcp.send sock, "\x01Hello server"
# send a fake chunk: p_type timestamp chunk_x chunk_z chunk_data
:gen_tcp.send sock, <<0::8, 1234::64, 98::32, 76::32, "this is a fake chunk">>
# be nice and close the connection
:gen_tcp.close sock
```
