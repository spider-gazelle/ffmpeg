require "../ffmpeg"

class FFmpeg::CodecParameters
  def initialize
    @params = LibAV::Codec.alloc_parameters
    @params_pointer = pointerof(@params)
  end

  @params : LibAV::Codec::AVCodecParameters
  @params_pointer : Pointer(LibAV::Codec::AVCodecParameters)

  def finalize
    LibAV::Codec.free_parameters(@params_pointer)
  end

  def to_unsafe
    @params
  end
end
