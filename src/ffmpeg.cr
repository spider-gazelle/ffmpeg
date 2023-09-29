require "log"
require "./ffmpeg/libav"
require "./ffmpeg/*"

module FFmpeg
  Log = ::Log.for("FFmpeg")

  {% begin %}
    VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}
  {% end %}

  def self.version
    String.new(LibAV::Util.version_info)
  end

  alias PixelFormat = LibAV::PixelFormat
  alias MediaType = LibAV::MediaType

  enum ScalingAlgorithm
    FastBilinear  =     1
    Bilinear      =     2
    Bicubic       =     4
    Experimental  =     8
    Neighbor      =  0x10
    Area          =  0x20
    Bicublin      =  0x40
    Gaussian      =  0x80
    Sinc          = 0x100
    Lanczos       = 0x200
    BicubicSpline = 0x400
  end

  def self.get_error_message(error : Int32)
    buffer = Bytes.new(64) # max error message length
    success = FFmpeg::LibAV::Util.strerror(error, buffer, buffer.size)
    return "unknown" if success < 0
    String.new(buffer.to_unsafe) # unsafe as it's \0 terminated
  end

  def self.mktag(a : Char, b : Char, c : Char, d : Char)
    (a.ord) | (b.ord << 8) | (c.ord << 16) | (d.ord.to_u << 24)
  end

  def self.fferrtag(a : Char, b : Char, c : Char, d : Char)
    -(mktag(a, b, c, d))
  end

  AVERROR_EOF = fferrtag('E', 'O', 'F', ' ')
end
