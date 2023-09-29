require "../video"

class FFmpeg::Video::File < FFmpeg::Video
  def initialize(filename : String | Path)
    @input = filename.to_s
    @io = ::File.open(filename)
  end

  getter input : String
  @io : ::File

  def close : Nil
    @io.close
  end

  def closed? : Bool
    @io.closed?
  end

  def seek(timestamp : Int64, style : SeekStyle = SeekStyle::None)
    status = LibAV::Util.seek_frame(format, @stream_index, 0_i64, style.value)
    if status < 0
      err = FFmpeg.get_error_message(status)
      raise "seek failed with #{status}: #{err}"
    end
    @codec.try &.flush_buffers
  end

  def configure_read
    Log.trace { "configuring IO callback" }
    @io = ::File.open(input) if closed?
    format.on_read { |bytes| @io.read(bytes) }
    format.on_seek do |seek_offset, from_position|
      case from_position
      in .start?
        @io.pos = seek_offset
      in .current?
        @io.pos += seek_offset
      in .end?
        @io.pos = @io.size + seek_offset
      in .size?
        @io.size
      end
    end
    format.configure_io
  end
end
