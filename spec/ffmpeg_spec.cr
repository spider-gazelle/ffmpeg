require "./spec_helper"

require "stumpy_core"
require "stumpy_png"

module FFmpeg
  describe FFmpeg do
    it "decodes a frame of a video file" do
      stream_url = "./test.mp4"
      format = FormatContext.new.open(stream_url).stream_info
      stream_index = format.find_best_stream MediaType::Video
      puts "found stream index #{stream_index}"

      format.dump_format stream_index
      params = format.parameters(stream_index)
      puts "found codec details"

      codec = CodecContext.new params
      codec.open
      puts "opened video stream"

      rgb_frame = Frame.new(codec.width, codec.height, 3)
      scaler = SWScaleContext.new(codec, output_format: :rgb24, scaling_method: :bicublin)
      puts "prepared scaler, #{codec.width}x#{codec.height} @ #{codec.pixel_format}"

      canvas = StumpyCore::Canvas.new(codec.width, codec.height, StumpyCore::RGBA::WHITE)
      write_frame = 60
      frame_count = 0
      finished = false

      loop do
        break if finished
        format.read do |packet|
          if packet.stream_index == stream_index
            if frame = codec.decode(packet)
              print "."
              frame_count += 1
              next if frame_count < write_frame

              scaler.scale(frame, rgb_frame)

              # copy frame into a stumpy canvas
              frame_buffer = rgb_frame.buffer
              (0...canvas.pixels.size).each do |index|
                idx = index * 3
                r = ((frame_buffer[idx] / UInt8::MAX) * UInt16::MAX).round.to_u16
                g = ((frame_buffer[idx + 1] / UInt8::MAX) * UInt16::MAX).round.to_u16
                b = ((frame_buffer[idx + 2] / UInt8::MAX) * UInt16::MAX).round.to_u16
                canvas.pixels[index] = StumpyCore::RGBA.new(r, g, b)
              end

              puts "writing output"
              StumpyPNG.write(canvas, "./output.png")
              finished = true
            else
              print "-"
            end
          end
        end
      end
    end
  end
end
