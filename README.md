# ffmpeg libav bindings for crystal lang

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

See the specs for usage

## Contributing

1. Fork it (<https://github.com/spider-gazelle/ffmpeg/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Stephen von Takach](https://github.com/stakach) - creator and maintainer
