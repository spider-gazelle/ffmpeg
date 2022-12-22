require "../video"
require "ipaddress"
require "socket"
require "uri"

class FFmpeg::Video::UDP < FFmpeg::Video
  MULTICASTRANGEV4 = IPAddress.new("224.0.0.0/4")
  MULTICASTRANGEV6 = IPAddress.new("ff00::/8")

  def initialize(stream : String | URI, read_buffer_size : Int = 1024 * 1024 * 4)
    uri = stream.is_a?(URI) ? stream : URI.parse(stream)
    @host = uri.host.as(String)
    @port = uri.port || 554

    @input = uri.to_s
    @io = UDPSocket.new
    @io.buffer_size = read_buffer_size
    @io.read_buffering = true
    @io.read_timeout = 2.seconds
  end

  getter input : String
  @io : UDPSocket
  getter host : String
  getter port : Int32

  def configure_read
    Log.trace { "connecting to stream" }
    if closed?
      read_buffer_size = @io.buffer_size
      @io = UDPSocket.new
      @io.buffer_size = read_buffer_size
      @io.read_buffering = true
      @io.read_timeout = 2.seconds
    end

    socket = @io

    begin
      ipaddr = IPAddress.new(host)
      if ipaddr.is_a?(IPAddress::IPv4) ? MULTICASTRANGEV4.includes?(ipaddr) : MULTICASTRANGEV6.includes?(ipaddr)
        socket.bind "0.0.0.0", @port
        socket.join_group(Socket::IPAddress.new(@host, @port))
      else
        socket.connect(@host, @port)
      end
    rescue ArgumentError
      # @ip is a hostname
      socket.connect(@host, @port)
    end

    Log.trace { "configuring IO callback" }
    format.on_read do |bytes|
      bytes_read, _client_addr = socket.receive(bytes)
      bytes_read
    end
  end
end
