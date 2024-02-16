require "stumpy_core"
require "../ffmpeg"

class FFmpeg::Frame
  def initialize
    @frame = LibAV::Util.frame_alloc
    raise "failed to allocate frame" if @frame.null?
    @frame_pointer = pointerof(@frame)
  end

  def initialize(source : FFmpeg::Frame)
    @frame = LibAV::Util.frame_clone(source)
    raise "failed to allocate frame" if @frame.null?
    @frame_pointer = pointerof(@frame)
    @buffer = source.buffer
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

  # crops the frame for use with scaler to combine cropping in a single operation
  def quick_crop(top : Int32, left : Int32, bottom : Int32, right : Int32) : FFmpeg::Frame?
    case pixel_format
    when .yuv420_p?, .yuvj420_p?
      new_frame = FFmpeg::Frame.new(self)
      new_frame.quick_crop_yuv420(top, left, bottom, right)
    when .rgb24?, .bgr24?
      new_frame = FFmpeg::Frame.new(self)
      new_frame.quick_crop_rgb(top, left, bottom, right)
    when .rgb48_le?, .rgb48_be?
      new_frame = FFmpeg::Frame.new(self)
      new_frame.quick_crop_rgb48(top, left, bottom, right)
    when .yuyv422?
      new_frame = FFmpeg::Frame.new(self)
      new_frame.quick_crop_uyvy(top, left, bottom, right)
    end
    new_frame
  end

  protected def quick_crop_yuv420(top : Int32, left : Int32, bottom : Int32, right : Int32) : Nil
    # adjust width and height
    @frame.value.height = height - top - bottom
    @frame.value.width = width - left - right
    # adjust pointers into buffer
    chroma_top = top // 2
    chroma_left = left // 2
    @frame.value.data[0] = @frame.value.data[0] + (top * @frame.value.linesize[0] + left)               # Y plane
    @frame.value.data[1] = @frame.value.data[1] + (chroma_top * @frame.value.linesize[1] + chroma_left) # U plane
    @frame.value.data[2] = @frame.value.data[2] + (chroma_top * @frame.value.linesize[2] + chroma_left) # V plane
  end

  protected def quick_crop_uyvy(top : Int32, left : Int32, bottom : Int32, right : Int32) : Nil
    # Adjust width and height. Note that the width should be an even number.
    @frame.value.height = height - top - bottom
    @frame.value.width = (width - left - right) & ~1

    # Adjust the pointer into the buffer.
    # Since UYVY is a packed format, we need to adjust the starting point of the data buffer.
    # We also need to ensure left is even to align correctly with the UYVY pairs.
    adjusted_left = left & ~1
    @frame.value.data[0] = @frame.value.data[0] + (top * @frame.value.linesize[0] + adjusted_left * 2)
  end

  protected def quick_crop_rgb(top : Int32, left : Int32, bottom : Int32, right : Int32) : Nil
    # adjust width and height
    @frame.value.height = height - top - bottom
    @frame.value.width = width - left - right
    # adjust pointers into buffer
    @frame.value.data[0] = @frame.value.data[0] + (top * @frame.value.linesize[0] + left * 3) # 3 bytes per pixel
  end

  protected def quick_crop_rgb48(top : Int32, left : Int32, bottom : Int32, right : Int32) : Nil
    # adjust width and height
    @frame.value.height = height - top - bottom
    @frame.value.width = width - left - right
    # adjust pointers into buffer
    @frame.value.data[0] = @frame.value.data[0] + (top * @frame.value.linesize[0] + left * 6) # 6 bytes per pixel
  end

  # crop helper - values are pixel distances from the edges
  # NOTE:: when streaming video you'd want to cache scalers. This is useful where
  # you need to crop different segments each frame
  def crop(top : Int32, left : Int32, bottom : Int32, right : Int32) : FFmpeg::Frame
    max_x = width
    max_y = height
    top = top.clamp(0, max_y)
    bottom = bottom.clamp(0, max_y)
    left = left.clamp(0, max_x)
    right = right.clamp(0, max_x)
    raise "crop is not valid: #{left},#{top} => #{right},#{bottom}" if (left + right) >= max_x || (top + bottom) >= max_y
    return self if top.zero? && left.zero? && bottom.zero? && right.zero?

    unsafe_crop(top, left, bottom, right)
  end

  def unsafe_crop(top : Int32, left : Int32, bottom : Int32, right : Int32) : FFmpeg::Frame
    # copy buffer if quick crop is supported
    if frame = quick_crop(top, left, bottom, right)
      new_frame = Frame.new(frame.width, frame.height, frame.pixel_format)
      frame.copy_to new_frame
      new_frame
    else
      # convert to a format that we can use quick crop with
      convert_to(:rgb24).unsafe_crop(top, left, bottom, right)
    end
  end

  # helper for converting to another format
  # NOTE:: when streaming video you'd want to cache this scaler.
  def convert_to(pixel_format : LibAV::PixelFormat) : FFmpeg::Frame
    new_frame = Frame.new(width, height, pixel_format)
    scaler = SWScale.new(width, height, self.pixel_format, width, height, pixel_format)
    scaler.scale(self, new_frame)
    new_frame
  end

  # copies the image buffer to a new frame
  def copy_to(frame : FFmpeg::Frame)
    raise ArgumentError.new("frame width, height and pixel format must match") unless frame.width == width && frame.height == height && frame.pixel_format == pixel_format
    LibAV::Util.frame_copy frame, self
    frame
  end

  # canvas helpers
  def self.new(canvas : StumpyCore::Canvas)
    frame = self.new(canvas.width, canvas.height, :rgb48Le)

    pixel_components = canvas.width * canvas.height * 3
    pointer = Pointer(UInt16).new(frame.buffer.to_unsafe.address)
    frame_buffer = Slice.new(pointer, pixel_components)

    # copy frame into a stumpy canvas
    canvas.pixels.each_with_index do |rgb, index|
      idx = index * 3
      frame_buffer[idx] = rgb.r
      frame_buffer[idx + 1] = rgb.g
      frame_buffer[idx + 2] = rgb.b
    end

    frame
  end

  # a very simple way to get a stumpy canvas from a frame
  # also very inefficient so I don't recommend using in production
  def to_canvas : StumpyCore::Canvas
    rgb_frame = pixel_format.rgb48_le? ? self : convert_to(:rgb48Le)

    pixel_components = width * height * 3
    pointer = Pointer(UInt16).new(rgb_frame.buffer.to_unsafe.address)
    frame_buffer = Slice.new(pointer, pixel_components)

    StumpyCore::Canvas.new(width, height) do |x, y|
      idx = (y * width * 3) + (x * 3)
      r = frame_buffer[idx]
      g = frame_buffer[idx + 1]
      b = frame_buffer[idx + 2]
      StumpyCore::RGBA.new(r, g, b)
    end
  end
end
