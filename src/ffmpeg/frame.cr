require "../ffmpeg"

class FFmpeg::Frame
  def initialize
    @frame = LibAV::Util.frame_alloc
    raise "failed to allocate frame" if @frame.null?
    @frame_pointer = pointerof(@frame)
  end

  def self.new(width : Int, height : Int, pixel_bytes : Int)
    frame = self.new
    frame.allocate_buffer(width, height, pixel_bytes)
  end

  @frame_pointer : Pointer(Pointer(LibAV::Util::AVFrame))
  @frame : Pointer(LibAV::Util::AVFrame)
  getter buffer : Bytes = Bytes.new(0)

  def finalize
    LibAV::Util.frame_free(@frame_pointer)
  end

  def to_unsafe
    @frame
  end

  def width
    @frame.value.width
  end

  def height
    @frame.value.height
  end

  def pixel_format : PixelFormat
    @frame.value.format
  end

  def key_frame? : Bool
    @frame.value.key_frame != 0
  end

  def allocate_buffer(width : Int, height : Int, pixel_bytes : Int)
    num_pixels = width * height
    line_size = width * pixel_bytes

    @buffer = Bytes.new(num_pixels * pixel_bytes)
    @frame.value.linesize[0] = line_size.to_i
    @frame.value.data[0] = @buffer.to_unsafe
    self
  end
end
