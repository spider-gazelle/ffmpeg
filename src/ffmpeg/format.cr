require "../ffmpeg"

class FFmpeg::Format
  def initialize(@buffer_size = 4 * 1024 * 1024)
    @context = LibAV::Format.alloc_context
    raise "failed to allocate context" if @context.null?
    # this is the value ffmpeg uses by default 5seconds
    @context.value.max_analyze_duration = 5000000
    @context_pointer = pointerof(@context)
  end

  @buffer_size : Int32
  @context_pointer : Pointer(Pointer(LibAV::Format::Context))
  @context : Pointer(LibAV::Format::Context)
  getter! input : String

  def open?
    !@input.nil?
  end

  def finalize
    LibAV::Format.close_input(@context_pointer)
  end

  def to_unsafe
    @context
  end

  @io_context : LibAV::Format::IOContext? = nil
  @callback_ref : Pointer(Void)? = nil

  enum SeekFrom
    Start   =       0
    Current =       1
    End     =       2
    Size    = 0x10000
  end

  def on_seek(&@on_seek : Int64, SeekFrom -> Int64)
  end

  def on_read(&@on_read : Bytes -> Int32)
  end

  @on_seek : Proc(Int64, SeekFrom, Int64)? = nil
  @on_read : Proc(Bytes, Int32)? = nil

  def configure_io
    callback_ptr = Box.box(self)
    @callback_ref = callback_ptr
    @io_context = io = LibAV::Format.alloc_io_context(Pointer(UInt8).null, 0, 0, callback_ptr, ->(boxed_klass, bytes_ptr, bytes_size) {
      # ensure we are non-blocking
      Fiber.yield

      # obtain the data requested
      bytes = Bytes.new(bytes_ptr, bytes_size)
      unboxed_klass = Box(FFmpeg::Format).unbox(boxed_klass)
      if read_callback = unboxed_klass.@on_read
        read_callback.call(bytes)
      else
        -1
      end
    }, Pointer(Void).null, ->(boxed_klass, seek_offset, from_position) {
      begin
        unboxed_klass = Box(FFmpeg::Format).unbox(boxed_klass)
        if seek_callback = unboxed_klass.@on_seek
          seek_callback.call(seek_offset, SeekFrom.from_value(from_position))
        else
          -1_i64
        end
      rescue error
        Log.warn(exception: error) { "failed to seek" }
        -1_i64
      end
    })
    raise "failed to allocate IO context" if io.null?

    @context.value.pb = io

    self
  end

  def open(input : String)
    raise "already open" if open?
    success = LibAV::Format.open_input(pointerof(@context), input, Pointer(Void).null, Pointer(Void).null)
    raise "failed to open stream with #{success}: #{FFmpeg.get_error_message(success)}" unless success.zero?
    @input = input
    self
  end

  def stream_info
    raise "must open a stream first" unless open?
    success = LibAV::Format.find_stream_info(@context, Pointer(Void).null)
    raise "failed to find stream info #{success}: #{FFmpeg.get_error_message(success)}" if success < 0
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

  # Lazy load the packet
  getter packet : Packet { Packet.new(@buffer_size) }

  def read(&)
    status = LibAV::Format.read_frame(@context, packet)
    raise "failed to read a frame with #{status}: #{FFmpeg.get_error_message(status)}" if status < 0

    begin
      yield packet
    ensure
      LibAV::Codec.packet_unref(packet)
    end
  end
end
