require "../ffmpeg"

class FFmpeg::SWScale
  def initialize(
    input_width : Int,
    input_height : Int,
    input_format : PixelFormat,
    output_width : Int? = nil,
    output_height : Int? = nil,
    output_format : PixelFormat = PixelFormat::Rgb24,
    scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin
  )
    @context = LibAV::SWScale.get_context(
      input_width.to_i, input_height.to_i, input_format,
      (output_width || input_width).to_i, (output_height || input_height).to_i, output_format, scaling_method.to_i,
      Pointer(Void).null, Pointer(Void).null, Pointer(Void).null
    )
    raise "could not create a scaling context " if @context.null?
  end

  def self.new(input : Frame, output : Frame, scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin)
    new(
      input.width, input.height, input.pixel_format,
      output.width, output.height, output.pixel_format,
      scaling_method
    )
  end

  def self.new(
    codec : Codec,
    output_width : Int? = nil,
    output_height : Int? = nil,
    output_format : PixelFormat = PixelFormat::Rgb24,
    scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin
  )
    new(
      codec.width, codec.height, codec.pixel_format,
      output_width || codec.width, output_height || codec.height, output_format,
      scaling_method
    )
  end

  @context : LibAV::SWScale::Context

  def finalize
    LibAV::SWScale.free_context(@context)
  end

  def scale(input : Frame, output : Frame)
    inp = input.to_unsafe
    outp = output.to_unsafe
    LibAV::SWScale.scale(@context, inp.value.data, inp.value.linesize, 0, input.height, outp.value.data, outp.value.linesize)
    output
  end
end
