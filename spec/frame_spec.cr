require "./spec_helper"

module FFmpeg
  describe FFmpeg::Frame do
    it "allocates an empty structure" do
      frame = Frame.new
      frame.width.should eq 0
      frame.height.should eq 0
      frame.buffer.size.should eq 0
      frame.to_unsafe.value.linesize.should eq StaticArray[0, 0, 0, 0, 0, 0, 0, 0]
    end

    it "allocates a formatted video frame" do
      frame = Frame.new(800, 600, PixelFormat::Yuv420P)
      # pp! frame.buffer.to_unsafe
      # pp! frame.to_unsafe.value
      frame.pixel_format.should eq PixelFormat::Yuv420P
      frame.width.should eq 800
      frame.height.should eq 600
      frame.buffer.size.should eq 720000
      frame.to_unsafe.value.linesize.should eq StaticArray[800, 400, 400, 0, 0, 0, 0, 0]
    end
  end
end
