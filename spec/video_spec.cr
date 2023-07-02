require "./spec_helper"

require "stumpy_core"
require "stumpy_png"

module FFmpeg
  describe FFmpeg::Video do
    Spec.before_each do
      File.delete?("./output.png")
      File.delete?("./output2.png")
    end

    it "calculates scaled size properly" do
      new_width, new_height = Video.scale_to_fit(800, 600, 300, 300)
      new_height.should eq 300
      new_width.should eq 400

      new_width, new_height = Video.scale_to_fit(600, 800, 300, 300)
      new_height.should eq 400
      new_width.should eq 300
    end

    it "uses helpers to decode video frames" do
      video = Video.open(Path.new("./test.mp4"))

      write_frame = 60
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame
        puts "writing output"
        StumpyPNG.write(frame, "./output.png")
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
        StumpyPNG.write(frame, "./output2.png")
        break
      end

      File.exists?("./output2.png").should be_true
    end

    it "skips frames while processing images" do
      video = Video.open(Path.new("./test.mp4"))

      ready = Channel(Nil).new(1)
      data = Channel(Tuple(StumpyCore::Canvas, Bool)).new(1)

      spawn do
        write_frame = 60
        frame_count = 0

        loop do
          ready.send nil
          frame, key_frame = data.receive
          frame_count += 1
          next if frame_count < write_frame
          puts "writing async output"
          StumpyPNG.write(frame, "./async_output.png")
          break
        end

        ready.close
        data.close
      end

      video.async_frames(ready, data)
      File.exists?("./async_output.png").should be_true
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
        StumpyPNG.write(frame, "./output3.png")
        break
      end
      File.exists?("./output3.png").should be_true
    end
  end
end
