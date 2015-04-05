require_relative 'websocket_server'

server = WebsocketServer.new

server.connect do |connection|
  puts "Connected"
  connection.listen do |message|
    puts "Received #{message}"
    connection.send("Received #{message}. Thanks!")
  end

end