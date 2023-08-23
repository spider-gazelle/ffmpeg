require "../ffmpeg"

class FFmpeg::Frame
  def initialize
    @frame = LibAV::Util.frame_alloc
    raise "failed to allocate frame" if @frame.null?
    @frame_pointer = pointerof(@frame)
  end

  @[Deprecated("specify pixel format instead of byte size")]
  def self.new(width : Int, height : Int, pixel_bytes : Int)
    frame = self.new
    frame.allocate_buffer(width, height, pixel_bytes)
  end

  def self.new(width : Int, height : Int, pixel_format : LibAV::PixelFormat, align : Int = 1, buffer : Bytes? = nil)
    frame = self.new
    frame.allocate_buffer(width, height, pixel_format, align, buffer)
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

  @[Deprecated("specify pixel format instead of byte size")]
  def allocate_buffer(width : Int, height : Int, pixel_bytes : Int)
    num_pixels = width * height
    line_size = width * pixel_bytes

    @buffer = Bytes.new(num_pixels * pixel_bytes)

    @frame.value.width = width.to_i
    @frame.value.height = height.to_i
    # NOTE:: this linesize is only valid for some formats (i.e RGB)
    @frame.value.linesize[0] = line_size.to_i
    @frame.value.data[0] = @buffer.to_unsafe
    self
  end

  def allocate_buffer(width : Int, height : Int, pixel_format : LibAV::PixelFormat, align : Int = 1, buffer : Bytes? = nil)
    if buffer
      @buffer = buffer
    else
      buffer_size = LibAV::Util.image_buffer_size(pixel_format, width.to_i, height.to_i, align.to_i)
      @buffer = Bytes.new(buffer_size)
    end

    # libav frames have a very specific buffer format
    result = LibAV::Util.image_fill_arrays(@frame.value.data, @frame.value.linesize, @buffer.to_unsafe, pixel_format, width.to_i, height.to_i, align.to_i)
    raise "failed to fill frame structure for image #{pixel_format}:#{width}x#{height} (#{result})" if result < 0

    @frame.value.width = width.to_i
    @frame.value.height = height.to_i
    @frame.value.format = pixel_format
    self
  end
end
