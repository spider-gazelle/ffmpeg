require "../ffmpeg"

class FFmpeg::Codec
  def initialize
    # NOTE:: removing this print causes alloc_context to fail??
    # actually stummped on how to resolve this
    print "\b"
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

  def decode(packet : Packet) : Frame?
    frame_finished = 0
    _bytes_allocated = LibAV::Codec.decode_video(@context, frame, pointerof(frame_finished), packet)
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
