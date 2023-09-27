# ffmpeg libav bindings for crystal lang

[![CI](https://github.com/spider-gazelle/ffmpeg/actions/workflows/ci.yml/badge.svg)](https://github.com/spider-gazelle/ffmpeg/actions/workflows/ci.yml)

Primarily to extract video frames from streams and files for processing by AI.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ffmpeg:
       github: spider-gazelle/ffmpeg
   ```

2. Run `shards install`
3. ensure the required libraries are installed
   * `sudo apt install libswscale-dev`
   * `sudo apt install libav-tools` or `sudo apt install ffmpeg`

## Usage

parsing a video file, outputs [StumpyCore Canvas](https://github.com/stumpycr/stumpy_core#stumpy_core)

```crystal

require "ffmpeg"

video = Video::File.new("./test.mp4")
video.each_frame do |frame, is_key_frame|
  frame           # => FFmpeg::Frame
  frame.to_canvas # => StumpyCore::Canvas
end

```

also supports UDP streams (unicast or multicast)

```crystal

require "ffmpeg"

video = Video::UDP.new("udp://239.0.0.2:1234")
video.each_frame do |frame, is_key_frame|
  frame           # => FFmpeg::Frame
  frame.to_canvas # => StumpyCore::Canvas
end

```

You can also scale the frames

```crystal

require "ffmpeg"

video = Video::File.new("./test.mp4")

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

video.each_frame do |frame, is_key_frame|
  scaler.scale frame, scaled_frame

  # do something with the scaled frame
  scaled_frame.to_canvas
end

```

See the specs for more detailed usage

## Contributing

1. Fork it (<https://github.com/spider-gazelle/ffmpeg/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stephen von Takach](https://github.com/stakach) - creator and maintainer
