require "stumpy_core"
require "../ffmpeg"
require "tasker"

abstract class FFmpeg::Video
  def finalize
    close
  end

  abstract def configure_read
  abstract def input : String
  abstract def close : Nil
  abstract def closed? : Bool

  def self.open(input : Path | URI)
    case input
    in Path
      Video::File.new(input)
    in URI
      case input.scheme.try(&.downcase)
      when "udp"
        Video::UDP.new(input)
      else
        raise ArgumentError.new("input URI scheme '#{input.scheme}' not supported")
      end
    end
  end

  getter format : Format = Format.new

  protected def configure(output_width, output_height, scaling_method)
    configure_read

    Log.trace { "opening UDP stream input" }
    format.open(input).stream_info
    stream_index = format.find_best_stream MediaType::Video
    # format.dump_format stream_index

    Log.trace { "configuring codec" }
    params = format.parameters(stream_index)
    codec = Codec.new params
    codec.open

    Log.trace { "calculating scaling / cropping requirements" }
    # We want to scale the image, maintaining the aspect ratio
    # then we'll crop the scaled image if required (based on the desired output)
    desired_width = output_width.try(&.to_i) || codec.width
    desired_height = output_height.try(&.to_i) || codec.height
    output_width, output_height = Video.scale_to_fit(codec.width, codec.height, desired_width, desired_height)

    requires_cropping = desired_width != output_width || desired_height != output_height

    Log.trace { "configuring scaler, input: #{codec.width}x#{codec.height} @ #{codec.pixel_format}, output: #{output_width}x#{output_height} @ rgb24" }
    rgb_frame = Frame.new(output_width, output_height, 6)
    scaler = SWScale.new(codec, output_width, output_height, :rgb48Le, scaling_method)
    canvas = StumpyCore::Canvas.new(output_width, output_height)
    cropped = StumpyCore::Canvas.new(desired_width, desired_height)

    # create a view into the frame buffer for simplified data extraction
    # works on the assumption that the code is running on a LE system
    pixel_components = output_width * output_height * 3
    pointer = Pointer(UInt16).new(rgb_frame.buffer.to_unsafe.address)
    frame_buffer = Slice.new(pointer, pixel_components)

    {codec, scaler, rgb_frame, frame_buffer, stream_index, canvas, cropped, requires_cropping}
  end

  protected def scale_and_extract(scaler, frame, rgb_frame, canvas, frame_buffer, requires_cropping, cropped)
    scaler.scale(frame, rgb_frame)

    # copy frame into a stumpy canvas
    canvas.pixels.size.times do |index|
      idx = index * 3
      r = frame_buffer[idx]
      g = frame_buffer[idx + 1]
      b = frame_buffer[idx + 2]
      canvas.pixels[index] = StumpyCore::RGBA.new(r, g, b)
    end

    output = requires_cropping ? Video.crop(canvas, cropped) : canvas
    {output, frame.key_frame?}
  end

  # Grab each frame and convert it to a StumpyCore::Canvas for simple manipulation
  # this can also scale the image to a preferred resolution
  def each_frame(
    output_width : Int? = nil,
    output_height : Int? = nil,
    scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin,
    &
  )
    codec, scaler, rgb_frame, frame_buffer, stream_index, canvas, cropped, requires_cropping = configure(output_width, output_height, scaling_method)

    Log.trace { "extracting frames" }
    while !closed?
      format.read do |packet|
        if packet.stream_index == stream_index
          if frame = codec.decode(packet)
            yield *scale_and_extract(scaler, frame, rgb_frame, canvas, frame_buffer, requires_cropping, cropped)
          end
        end
      end
    end
  ensure
    close
    @format = Format.new
    GC.collect
  end

  def frame_pipeline(
    pipeline : Tasker::Pipeline,
    output_width : Int? = nil,
    output_height : Int? = nil,
    scaling_method : ScalingAlgorithm = ScalingAlgorithm::Bicublin
  )
    codec, scaler, rgb_frame, frame_buffer, stream_index, canvas, cropped, requires_cropping = configure(output_width, output_height, scaling_method)

    Log.trace { "extracting frames" }
    while !closed? && !pipeline.closed?
      format.read do |packet|
        if packet.stream_index == stream_index
          if (frame = codec.decode(packet)) && pipeline.idle?
            pipeline.process scale_and_extract(scaler, frame, rgb_frame, canvas, frame_buffer, requires_cropping, cropped)
          else
            Log.trace { "skipping frame" }
          end
        end
      end
    end
  rescue Channel::ClosedError
  ensure
    close
    @format = Format.new
    GC.collect
  end

  def self.scale_to_fit(input_width : Int32, input_height : Int32, desired_width : Int32, desired_height : Int32) : Tuple(Int32, Int32)
    # Calculate the aspect ratio of the input resolution
    aspect_ratio = input_width / input_height

    # Calculate the aspect ratio of the desired resolution
    desired_aspect_ratio = desired_width / desired_height

    # If the aspect ratio of the input resolution is greater than the aspect ratio of the desired resolution,
    # that means the input resolution is wider than the desired resolution, so we should scale the width down
    # to the desired width and calculate the new height based on the aspect ratio.
    if aspect_ratio > desired_aspect_ratio
      return {(desired_height.to_f * aspect_ratio).to_i, desired_height}
    end

    # If the aspect ratio of the input resolution is less than the aspect ratio of the desired resolution,
    # that means the input resolution is taller than the desired resolution, so we should scale the height down
    # to the desired height and calculate the new width based on the aspect ratio.
    if aspect_ratio < desired_aspect_ratio
      return {desired_width, (desired_width / aspect_ratio).to_i}
    end

    # If the aspect ratios are equal, then the input resolution already has the same aspect ratio as the desired
    # resolution, so we can just return the desired resolution as-is.
    {desired_width, desired_height}
  end

  # one of desired_width or desired_height will match the canvas width or height
  # so we only have to crop width or height
  def self.crop(canvas : StumpyCore::Canvas, cropped : StumpyCore::Canvas)
    desired_width = cropped.width
    desired_height = cropped.height
    x_start = {(canvas.width - desired_width) // 2, 0}.max
    y_start = {(canvas.height - desired_height) // 2, 0}.max

    pixel = 0
    y_start.upto(y_start + desired_height - 1) do |y|
      x_start.upto(x_start + desired_width - 1) do |x|
        cropped.pixels[pixel] = canvas.pixels[y * canvas.width + x]
        pixel += 1
      end
    end

    cropped
  end
end

require "./video/*"
