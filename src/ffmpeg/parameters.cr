require "../ffmpeg"

class FFmpeg::Parameters
  def initialize
    @params = LibAV::Codec.alloc_parameters
    @params_pointer = pointerof(@params)
    @cleanup = true
  end

  def initialize(@params)
    @params_pointer = pointerof(@params)
    @cleanup = false
  end

  @params : LibAV::Codec::AVCodecParameters
  @params_pointer : Pointer(LibAV::Codec::AVCodecParameters)
  @cleanup : Bool

  def finalize
    LibAV::Codec.free_parameters(@params_pointer) if @cleanup
  end

  def to_unsafe
    @params
  end
end
