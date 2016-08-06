# AsyncServer

AsyncServer (Asynchronous Server) is an implementation of a queue like protocol for sending/receiving messages over tcp/ssl sockets.

A client connects to the socket and continuously writes a stream of data, with each message having the structure `n-bytes-message-length`+`message`. The server reads the first n bytes to determine length of the message, then reads the next <length> bytes.

Messages are tagged and then forwarded to internal services through a redis queue.

Responses are read from redis and sent to the respective client using the same message structure as above.

This implementation fits best situations where a request/response cycle is non viable/kludgy to do (polling for responses). eg due to external api calls necessary to process a request. 


## Assumptions
Clients connect from static IP addresses, probably allowed in through firewall rules. Messages are tagged and routed based on the IP addresses of the sender.



## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add async_server to your list of dependencies in `mix.exs`:

        def deps do
          [{:async_server, "~> 0.0.1"}]
        end

  2. Ensure async_server is started before your application:

        def application do
          [applications: [:async_server]]
        end

