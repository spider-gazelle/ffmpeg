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

    it "converts to and from stumpy canvas" do
      checkerboard = StumpyCore::Canvas.new(250, 250) do |x, y|
        if ((x // 32) + (y // 32)).odd?
          StumpyCore::RGBA.from_hex("#ffffff")
        else
          StumpyCore::RGBA.from_hex("#000000")
        end
      end

      frame = Frame.new checkerboard
      canvas = frame.to_canvas

      checkerboard.should eq canvas
    end

    it "crops images using quick crop yuv420" do
      width, height = 60, 60
      checkerboard = StumpyCore::Canvas.new(width, height) do |x, y|
        if ((x // 32) + (y // 32)).odd?
          StumpyCore::RGBA.from_hex("#ffffff")
        else
          StumpyCore::RGBA.from_hex("#000000")
        end
      end
      frame = Frame.new checkerboard

      StumpyPNG.write(checkerboard, "./checkerboard.png")

      # convert to yuv420
      yuv_frame = Frame.new(width, height, :yuv420_p)
      scaler = SWScale.new(width, height, frame.pixel_format, width, height, :yuv420_p)
      scaler.scale(frame, yuv_frame)

      # we can quick crop this frame
      sub_frame = yuv_frame.quick_crop(20, 20, 20, 20)
      raise "should return a sub frame" unless sub_frame

      width, height = sub_frame.width, sub_frame.height
      new_frame = Frame.new(width, height, :rgb48Le)
      scaler = SWScale.new(width, height, :yuv420_p, width, height, :rgb48Le)
      scaler.scale(sub_frame, new_frame)
      new_canvas = new_frame.to_canvas

      # check the output
      new_canvas.width.should eq 20
      new_canvas.height.should eq 20

      slow_crop = StumpyResize.crop checkerboard, 20, 20, 40, 40
      StumpyPNG.write(new_canvas, "./checkerboard-fast-crop.png")
      StumpyPNG.write(slow_crop, "./checkerboard-slow-crop.png")
    end

    it "crops images using quick crop rgb24" do
      width, height = 60, 60
      checkerboard = StumpyCore::Canvas.new(width, height) do |x, y|
        if ((x // 32) + (y // 32)).odd?
          StumpyCore::RGBA.from_hex("#ffffff")
        else
          StumpyCore::RGBA.from_hex("#000000")
        end
      end
      frame = Frame.new checkerboard

      # convert to rgb24
      rgb_frame = Frame.new(width, height, :rgb24)
      scaler = SWScale.new(width, height, frame.pixel_format, width, height, :rgb24)
      scaler.scale(frame, rgb_frame)

      # we can quick crop this frame
      sub_frame = rgb_frame.quick_crop(20, 20, 20, 20)
      raise "should return a sub frame" unless sub_frame

      width, height = sub_frame.width, sub_frame.height
      new_frame = Frame.new(width, height, :rgb48Le)
      scaler = SWScale.new(width, height, :rgb24, width, height, :rgb48Le)
      scaler.scale(sub_frame, new_frame)
      new_canvas = new_frame.to_canvas

      # check the output
      new_canvas.width.should eq 20
      new_canvas.height.should eq 20

      slow_crop = StumpyResize.crop checkerboard, 20, 20, 40, 40
      StumpyPNG.write(new_canvas, "./checkerboard-fast-crop-rgb.png")
      StumpyPNG.write(slow_crop, "./checkerboard-slow-crop-rgb.png")

      # SW Scaler seems to lose some colour accuracy when performing scales
      # new_canvas.should eq slow_crop
    end

    it "crops the image using the crop helper" do
      width, height = 60, 60
      checkerboard = StumpyCore::Canvas.new(width, height) do |x, y|
        if ((x // 32) + (y // 32)).odd?
          StumpyCore::RGBA.from_hex("#ffffff")
        else
          StumpyCore::RGBA.from_hex("#000000")
        end
      end
      frame = Frame.new checkerboard

      sub_frame = frame.crop(20, 20, 20, 20)
      sub_frame.width.should eq 20
      sub_frame.height.should eq 20

      StumpyPNG.write(sub_frame.to_canvas, "./checkerboard-crop-helper.png")
    end
  end
end
