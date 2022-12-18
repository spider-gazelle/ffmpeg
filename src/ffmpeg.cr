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
end
