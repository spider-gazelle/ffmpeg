require "../ffmpeg"

class FFmpeg::SWScale
  def initialize(
    input_width : Int,
    input_height : Int,
    @input_format : PixelFormat,
    output_width : Int? = nil,
    output_height : Int? = nil,
    @output_format : PixelFormat = PixelFormat::Rgb24,
    @scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin
  )
    @input_width = input_width.to_i
    @input_height = input_height.to_i
    @output_width = (output_width || input_width).to_i
    @output_height = (output_height || input_height).to_i
    @context = LibAV::SWScale.get_context(
      @input_width, @input_height, @input_format,
      @output_width, @output_height, @output_format, @scaling_method.to_i,
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

  getter input_width : Int32
  getter input_height : Int32
  getter output_width : Int32
  getter output_height : Int32
  getter input_format : PixelFormat
  getter output_format : PixelFormat
  getter scaling_method : ScalingAlgorithm

  # lazy init an output frame if one isn't provided
  getter output_frame : Frame do
    FFmpeg::Frame.new(@output_width, @output_height, @output_format)
  end

  # scales and optionally changes format of a frame
  def scale(input : Frame, output : Frame = output_frame)
    raise "input dimensions #{input.width}x#{input.height} don't match scaler dimensions #{@input_width}x#{@input_height}" unless input.width == @input_width && input.height == @input_height
    raise "output dimensions #{output.width}x#{output.height} don't match scaler dimensions #{@output_width}x#{@output_height}" unless output.width == @output_width && output.height == @output_height
    unsafe_scale input, output
  end

  # like scale but without the checks if you need the speed
  def unsafe_scale(input : Frame, output : Frame = output_frame)
    inp = input.to_unsafe
    outp = output.to_unsafe
    LibAV::SWScale.scale(@context, inp.value.data, inp.value.linesize, 0, input.height, outp.value.data, outp.value.linesize)
    output
  end

  def self.scale(input : Frame, width : Int32, height : Int32, output_format : PixelFormat = PixelFormat::Rgb24, scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin) : Frame
    new(
      input.width, input.height, input.pixel_format,
      width, height, output_format, scaling_method
    ).unsafe_scale(input)
  end
end
