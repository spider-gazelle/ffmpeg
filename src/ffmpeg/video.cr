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
  getter stream_index : Int32 = -1

  def on_codec(&@on_codec : Codec ->)
  end

  # if no flags then it seeks forward from the time requested
  @[Flags]
  enum SeekStyle
    Backward = 1 # first keyframe before the time requested
    Byte     = 2 # instead of a timestamp, jump to a particular byte
    Any      = 4 # closest frame, not a keyframe
    Frame    = 8 # instead of a timestamp, use frame numbering
  end

  def seek(timestamp : Int64, style : SeekStyle = SeekStyle::None)
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

    @stream_index = stream_index
    @codec = codec
    @on_codec.try &.call(codec)

    seek(0, SeekStyle::Frame)

    begin
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
    rescue error : IO::EOFError
      codec.decode(nil) do |frame|
        yield frame
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
