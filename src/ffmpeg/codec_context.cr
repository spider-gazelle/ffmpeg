require "../ffmpeg"

class FFmpeg::CodecContext
  def initialize
    # NOTE:: removing this puts causes alloc_context to fail??
    puts "alloc_context3"
    context = LibAV::Codec.alloc_context
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

  def self.new(parameters : CodecParameters)
    codec = CodecContext.new
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

  def parameters
    params = CodecParameters.new
    success = LibAV::Codec.parameters_from_context(params, @context)
    raise "failed to obtain parameters from context with #{success}" if success < 0
    params
  end

  def parameters=(params : CodecParameters)
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

  def decode(packet : Packet) : Frame?
    frame_finished = 0
    bytes_allocated = LibAV::Codec.decode_video(@context, frame, pointerof(frame_finished), packet)
    frame if frame_finished != 0
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
