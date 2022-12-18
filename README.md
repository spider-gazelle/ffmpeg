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
   frame # => StumpyCore::Canvas
end

```

also supports UDP streams (unicast or multicast)

```crystal

require "ffmpeg"

video = Video::UDP.new("udp://239.0.0.2:1234")
video.each_frame do |frame, is_key_frame|
   frame # => StumpyCore::Canvas
end

```

Frames can be scaled as they are processed.
If the new resolution isn't in the same aspect ratio then the image is scaled to cover.
That is both its height and width completely cover the source image and cropped either vertically or horizontally.

```crystal
video.each_frame(new_width, new_height) do |frame, is_key_frame|
   frame # => StumpyCore::Canvas
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
