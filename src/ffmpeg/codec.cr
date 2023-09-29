require "../ffmpeg"

class FFmpeg::Codec
  def initialize
    context = LibAV::Codec.alloc_context(Pointer(Void).null.as(LibAV::Codec::AVCodec))
    raise "failed to allocate context" if context.null?
    @context = context
    @context_pointer = pointerof(@context)
    @cleanup = true
  end

  def initialize(context : Pointer(LibAV::Codec::Context))
    @context = context
    @context_pointer = pointerof(@context)
    @cleanup = false
  end

  def self.new(parameters : Parameters)
    codec = self.new
    codec.parameters = parameters
    codec
  end

  @context_pointer : Pointer(Pointer(LibAV::Codec::Context))
  @context : Pointer(LibAV::Codec::Context)
  @cleanup : Bool

  private def context
    @context.value
  end

  def finalize
    LibAV::Codec.free_context(@context_pointer) if @cleanup && !@context.null?
  end

  def flush_buffers
    LibAV::Codec.flush_buffers(@context)
  end

  def parameters
    params = Parameters.new
    success = LibAV::Codec.parameters_from_context(params, @context)
    raise "failed to obtain parameters from context with #{success}" if success < 0
    params
  end

  def parameters=(params : Parameters)
    LibAV::Codec.parameters_to_context(@context, params)
    params
  end

  private getter codec : LibAV::Codec::AVCodec do
    c = LibAV::Codec.find_decoder(context.codec_id)
    raise "failed to find decoder for codec #{context.codec_id}" if c.null?
    c
  end

  def open
    success = LibAV::Codec.open2(@context, codec, Pointer(Void).null)
    raise "failed to open codec" if success < 0
    self
  end

  getter frame : Frame { Frame.new }

  def decode(packet : Packet, &)
    success = LibAV::Codec.send_packet(@context, packet)
    raise "failed to read packet with #{success}" if success < 0

    loop do
      break unless LibAV::Codec.receive_frame(@context, frame) == 0
      yield frame
    end
  end

  def width
    context.width
  end

  def height
    context.height
  end

  def pixel_format
    context.pix_fmt
  end
end
