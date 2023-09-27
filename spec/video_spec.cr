require "./spec_helper"

require "stumpy_core"
require "stumpy_png"

module FFmpeg
  describe FFmpeg::Video do
    before_all do
      File.delete?("./output.png")
      File.delete?("./output2.png")
      File.delete?("./output3.png")
      File.delete?("./output4.png")
    end

    it "uses helpers to decode video frames" do
      video = Video.open(Path.new("./test.mp4"))

      write_frame = 60
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame
        puts "writing output"
        StumpyPNG.write(frame.to_canvas, "./output.png")
        break
      end

      File.exists?("./output.png").should be_true

      # tests we can re-use the helper
      write_frame = 200
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame
        puts "writing output"
        StumpyPNG.write(frame.to_canvas, "./output2.png")
        break
      end

      File.exists?("./output2.png").should be_true
    end

    it "works with streams" do
      pending!("start a stream to test")
      video = Video.open URI.parse("udp://239.0.0.2:1234")
      write_frame = 60
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame
        puts "writing output"
        StumpyPNG.write(frame.to_canvas, "./output3.png")
        break
      end
      File.exists?("./output3.png").should be_true
    end

    it "works with scaling frames" do
      video = Video.open(Path.new("./test.mp4"))

      # the scaler context
      scaler = uninitialized FFmpeg::SWScale

      # scaled frame we'll use for storing the scaling output
      scaled_frame = uninitialized FFmpeg::Frame

      video.on_codec do |codec|
        # scale by 50%
        width = codec.width // 2
        height = codec.height // 2
        scaler = FFmpeg::SWScale.new(codec, width, height, codec.pixel_format)
        scaled_frame = FFmpeg::Frame.new width, height, codec.pixel_format
      end

      write_frame = 60
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame

        scaler.scale frame, scaled_frame

        puts "writing output"
        StumpyPNG.write(scaled_frame.to_canvas, "./output4.png")
        break
      end

      File.exists?("./output4.png").should be_true
    end
  end
end
