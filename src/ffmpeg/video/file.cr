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

  def configure_read
    Log.trace { "configuring IO callback" }
    @io = ::File.open(input) if closed?
    format.on_read { |bytes| @io.read(bytes) }
  end
end
