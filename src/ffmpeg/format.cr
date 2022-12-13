require "../ffmpeg"

class FFmpeg::Format
  def initialize
    @context = LibAV::Format.alloc_context
    raise "failed to allocate context" if @context.null?
    @context_pointer = pointerof(@context)
  end

  @context_pointer : Pointer(Pointer(LibAV::Format::Context))
  @context : Pointer(LibAV::Format::Context)
  getter! input : String

  def open?
    !@input.nil?
  end

  def finalize
    LibAV::Format.close_input(@context_pointer)
  end

  @io_context : LibAV::Format::IOContext? = nil
  @callback_ref : Pointer(Void)? = nil

  # Slice => bytes read
  def on_read(&callback : Bytes -> Int32)
    # we need our callback to be available
    callback_ptr = Box.box(callback)
    @callback_ref = callback_ptr
    @io_context = io = LibAV::Format.alloc_io_context(Pointer(UInt8).null, 0, 0, callback_ptr, ->(boxed_callback, bytes_ptr, bytes_size) {
      # ensure we are non-blocking
      Fiber.yield

      # obtain the data requested
      bytes = Bytes.new(bytes_ptr, bytes_size)
      unboxed_callback = Box(typeof(callback)).unbox(boxed_callback)
      unboxed_callback.call(bytes)
    }, Pointer(Void).null, Pointer(Void).null)
    raise "failed to allocate IO context" if io.null?

    @context.value.pb = io

    self
  end

  def open(input : String)
    raise "already open" if open?
    success = LibAV::Format.open_input(pointerof(@context), input, Pointer(Void).null, Pointer(Void).null)
    raise "failed to open stream with #{success}" unless success.zero?
    @input = input
    self
  end

  def stream_info
    raise "must open a stream first" unless open?
    success = LibAV::Format.find_stream_info(@context, Pointer(Void).null)
    raise "failed to find stream info #{success}" if success < 0
    self
  end

  def find_best_stream(media_type : MediaType = MediaType::Video)
    raise "must open a stream first" unless open?
    video_stream_index = LibAV::Codec.find_best_stream(@context, LibAV::MediaType::Video, -1, -1, Pointer(Void).null, 0)
    raise "failed to find valid stream" if video_stream_index < 0
    video_stream_index
  end

  def dump_format(stream_index : Int, is_output : Bool = false)
    LibAV::Codec.dump_format(@context, stream_index.to_i, input, is_output ? 1 : 0)
    self
  end

  def parameters(stream_index : Int)
    # codec_ctx = Codec.new @context.value.streams[stream_index].value.codec
    # codec_ctx.parameters
    Parameters.new(@context.value.streams[stream_index].value.codecpar)
  end

  # 4MB buffer
  getter packet : Packet { Packet.new(4 * 1024 * 1024) }

  def read
    status = LibAV::Format.read_frame(@context, packet)
    raise "failed to read a frame with #{status}" if status < 0
    begin
      yield packet
    ensure
      LibAV::Codec.packet_unref(packet)
    end
  end
end
