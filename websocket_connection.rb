class WebsocketConnection

  WS_MAGIC_STRING = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  OPCODE_TEXT = 0x01

  attr_reader :socket, :path

  def initialize(socket, path)
    @socket, @path = socket, path
  end

  def handshake 
      request = socket.gets
      STDERR.puts request

      if request =~ /GET #{path}/
        header = get_header
        return false if !(header =~ /Sec-WebSocket-Key: (.*)\r\n/)
        ws_accept = create_websocket_accept($1)
        send_handshake_response(ws_accept)
        return true
      end
      false
  end

  def listen
    Thread.new do
      loop do

        first_byte, length_indicator = socket.read(2).bytes

        length_indicator -= 128

        length =  if length_indicator <= 125
                    length_indicator
                  elsif length_indicator == 126
                    socket.read(2).unpack("n")[0]
                  else
                    socket.read(8).unpack("n")[0] # this is wrong
                  end

        keys = socket.read(4).bytes
        encoded = socket.read(length).bytes

        message = encoded.each_with_index.map do |byte, index| 
          byte ^ keys[index % 4] 
        end.pack("c*")

        yield(message)
      end
    end
  end

  def send(message)
    bytes = [0x80 | OPCODE_TEXT]
    size = message.bytesize

    bytes +=  if size <= 125
                [size]
              elsif size < 2**16
                [126] + [size].pack("n").bytes
              else
                [127] + [size].pack("n").bytes # also wrong
              end 

    bytes += message.bytes
    send_data = bytes.pack("C*")
    socket << send_data
  end

  private

  def get_header(header = "")
    (line = socket.gets) == "\r\n" ? header : get_header(header + line)
  end

  def send_handshake_response(ws_accept)
    socket << "HTTP/1.1 101 Switching Protocols\r\n" +
      "Upgrade: websocket\r\n" +
      "Connection: Upgrade\r\n" +
      "Sec-WebSocket-Accept: #{ws_accept}\r\n"    
  end

  def create_websocket_accept(key)
    accept = Digest::SHA1.digest(key + WS_MAGIC_STRING)
    Base64.encode64(accept)
  end

end