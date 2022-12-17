require "./spec_helper"

require "stumpy_core"
require "stumpy_png"

module FFmpeg
  describe FFmpeg::Video do
    Spec.before_each { File.delete?("./output.png") }

    it "uses helpers to decode video frames" do
      video = Video::File.new("./test.mp4")

      write_frame = 60
      frame_count = 0
      video.each_frame do |frame|
        frame_count += 1
        next if frame_count < write_frame
        puts "writing output"
        StumpyPNG.write(frame, "./output.png")
        break
      end

      video.close
      File.exists?("./output.png").should be_true
    end
  end
end
