require "stumpy_core"
require "../ffmpeg"
require "uri"

abstract class FFmpeg::Video
  def finalize
    @io.close
  end

  abstract def configure_read
  abstract def input : String
  abstract def format : Format

  def close
    @io.close
  end

  def closed?
    @io.closed?
  end

  def each_frame
    configure_read

    Log.trace { "opening UDP stream input" }
    format.open(input).stream_info
    stream_index = format.find_best_stream MediaType::Video
    # format.dump_format stream_index

    Log.trace { "configuring codec" }
    params = format.parameters(stream_index)
    codec = Codec.new params
    codec.open

    Log.trace { "configuring scaler, #{codec.width}x#{codec.height} @ #{codec.pixel_format}" }
    rgb_frame = Frame.new(codec.width, codec.height, 3)
    scaler = SWScale.new(codec, output_format: :rgb24, scaling_method: :bicublin)
    canvas = StumpyCore::Canvas.new(codec.width, codec.height, StumpyCore::RGBA::WHITE)

    Log.trace { "extracting frames" }
    while !@io.closed?
      format.read do |packet|
        if packet.stream_index == stream_index
          if frame = codec.decode(packet)
            scaler.scale(frame, rgb_frame)

            # copy frame into a stumpy canvas
            frame_buffer = rgb_frame.buffer
            (0...canvas.pixels.size).each do |index|
              idx = index * 3
              r = ((frame_buffer[idx] / UInt8::MAX) * UInt16::MAX).round.to_u16
              g = ((frame_buffer[idx + 1] / UInt8::MAX) * UInt16::MAX).round.to_u16
              b = ((frame_buffer[idx + 2] / UInt8::MAX) * UInt16::MAX).round.to_u16
              canvas.pixels[index] = StumpyCore::RGBA.new(r, g, b)
            end

            yield canvas
          end
        end
      end
    end
  end

  class File < Video
    def initialize(filename : String)
      @input = filename
      @format = Format.new
      @io = ::File.open(filename)
    end

    getter input : String
    getter format : Format
    @io : ::File

    def configure_read
      Log.trace { "configuring IO callback" }
      format.on_read { |bytes| @io.read(bytes) }
    end
  end

  class UDP < Video
    def initialize(stream : String, read_buffer_size : Int = 1024 * 1024 * 4)
      uri = URI.parse stream
      @host = uri.host
      @port = uri.port || 554

      @input = stream
      @format = Format.new
      @io = UDPSocket.new
      @io.buffer_size = read_buffer_size
      @io.read_buffering = true
      @io.read_timeout = 2.seconds
    end

    getter input : String
    getter format : Format
    @io : UDPSocket
    getter host : String
    getter port : Int32

    def configure_read
      Log.trace { "connecting to stream" }
      begin
        ipaddr = IPAddress.new(@host, @port)
        if ipaddr.is_a?(IPAddress::IPv4) ? MULTICASTRANGEV4.includes?(ipaddr) : MULTICASTRANGEV6.includes?(ipaddr)
          socket.bind "0.0.0.0", @port
          socket.join_group(ipaddr)
        else
          socket.connect(@host, @port)
        end
      rescue ArgumentError
        # @ip is a hostname
        socket.connect(@host, @port)
      end

      Log.trace { "configuring IO callback" }
      format.on_read do |bytes|
        bytes_read, client_addr = socket.receive(bytes)
        bytes_read
      end
    end
  end
end