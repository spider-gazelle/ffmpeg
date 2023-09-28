require "../ffmpeg"

abstract class FFmpeg::Video
  def finalize
    close
  end

  abstract def configure_read
  abstract def input : String
  abstract def close : Nil
  abstract def closed? : Bool

  def self.open(input : Path | URI)
    case input
    in Path
      Video::File.new(input)
    in URI
      case input.scheme.try(&.downcase)
      when "udp"
        Video::UDP.new(input)
      else
        raise ArgumentError.new("input URI scheme '#{input.scheme}' not supported")
      end
    end
  end

  getter format : Format = Format.new
  getter codec : Codec? = nil

  def on_codec(&@on_codec : Codec ->)
  end

  protected def configure
    configure_read

    Log.trace { "opening #{self.class.to_s.split("::")[-1]} stream input" }
    format.open(input).stream_info
    stream_index = format.find_best_stream MediaType::Video
    # format.dump_format stream_index

    Log.trace { "configuring codec" }
    params = format.parameters(stream_index)
    codec = Codec.new params
    codec.open

    {codec, stream_index}
  end

  # Grab each frame
  def each_frame(&)
    codec, stream_index = configure

    @codec = codec
    @on_codec.try &.call(codec)

    Log.trace { "extracting frames" }
    while !closed?
      format.read do |packet|
        if packet.stream_index == stream_index
          codec.decode(packet) do |frame|
            yield frame
          end
        end
      end
    end
  ensure
    close
    @format = Format.new
    @codec = nil
    GC.collect
  end
end

require "./video/*"
