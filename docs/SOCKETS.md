# Robe Sockets

With credit and thanks to @jgaskins for [PowerStrip](`https://github.com/clearwater-rb/power_strip`) from which we have borrowed massively.

### Servers

Rack causes problems for WebSockets when in development mode, due to something in its added middleware. 

To get around this don't run server via `rackup`.

Instead use `puma` or `thin` directly.

`bundle exec puma config.ru -p 9292`

or

`bundle exec thin start --rackup config.ru -p 9292`    

THIN seems better for debugging errors in server web socket code - its fails with a stack trace. Puma just fails.

Ensure gemfile includes `puma` or `thin` as required. 

Also ensure `config.ru` does not execute server in first line.

### Roda

```ruby
# config.ru
require 'robe/server/sockets'

Robe::Server::Sockets.start

class MyApp < Roda
  Robe::Server::Sockets.route(r)
end
```

### Sending updates to clients:

```ruby
Robe::Server::Sockets[channel_name].send(event_name, key: value)
```

## Client-Side Usage

```ruby
require 'opal'
require 'robe/client/socket'

# This URL should point to where you have Sockets mounted on the server
client = Robe::Client::Socket.new(url: 'ws://localhost:9292/ops')

client.on(:connect) do 
  # some action which sets socket connection state in app
end

client.on(:disconnect) do
  # some action which sets socket connection state in app
end

channel = client.subscribe(:chat)

channel.on :message do |message|
  # Tell the app you've received this message. 
  # The payload is in message.data.
  puts "channel => #{channel.name} : event => #{message.event} : data => #{message.data}"
end
```

## Sending Messages Client->Server

Set up a message handler on the server:

```ruby
require 'robe/server/sockets'

# Handle :message events in the "sockets" channel.
# @param message [Robe::Server::Sockets::Message] the message we received
# @param connection [Faye::WebSocket] the client connection this is from
Robe::Server::Sockets.on(:message, channel: 'sockets') do |message, _connection|
  Robe::Server::Task.perform_async(message)
end
```

Notice we don't do work directly on the message. We instead pass it off to a background worker. This is so that we can handle as many incoming messages as possible. To be able to send messages back to that channel, we can simply use the Server->Client message command specified above. Note the `perform` method here:

```ruby
require 'sidekiq'
require 'robe/server/sockets'

class Robe::Server::Task
  include Sidekiq::Worker

  # @param message [Robe::Server::Sockets::Message]
  def perform(message)
    # Simplest case, we send the message back out to everyone on the same channel
    Robe::Server::Sockets[message.channel].send :message, message.data
  end
end
```

## Authentication/authorization

#### From Heroku

The WebSocket protocol doesn’t handle authorization or authentication. 

Practically, this means that a WebSocket opened from a page behind auth doesn’t “automatically” receive any sort of auth; you need to take steps to also secure the WebSocket connection.

This can be done in a variety of ways, as WebSockets will pass through standard HTTP headers commonly used for authentication. 

This means you could use the same authentication mechanism you’re using for your web views on WebSocket connections as well.

Since you cannot customize WebSocket headers from JavaScript, you’re limited to the “implicit” auth (i.e. Basic or cookies) that’s sent from the browser. Further, it’s common to have the server that handles WebSockets be completely separate from the one handling “normal” HTTP requests. This can make shared authorization headers difficult or impossible.

So, one pattern we’ve seen that seems to solve the WebSocket authentication problem well is a “ticket”-based authentication system. Broadly speaking, it works like this:

When the client-side code decides to open a WebSocket, it contacts the HTTP server to obtain an authorization “ticket”.

The server generates this ticket. It typically contains some sort of user/account ID, the IP of the client requesting the ticket, a timestamp, and any other sort of internal record keeping you might need.

The server stores this ticket (i.e. in a database or cache), and also returns it to the client.

The client opens the WebSocket connection, and sends along this “ticket” as part of an initial handshake.

The server can then compare this ticket, check source IPs, verify that the ticket hasn’t been re-used and hasn’t expired, and do any other sort of permission checking. If all goes well, the WebSocket connection is now verified.

[Thanks to Armin Ronacher for first bringing this pattern to our attention.]

#### See also

http://blog.stratumsecurity.com/2016/06/13/websockets-auth/