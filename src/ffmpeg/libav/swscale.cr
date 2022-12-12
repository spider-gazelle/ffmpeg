require "../libav"

module FFmpeg::LibAV
  @[Link("swscale")]
  lib SWScale
    type Context = Void*

    # flags https://ffmpeg.org/doxygen/3.4/swscale_8h_source.html
    FAST_BILINEAR =     1
    BILINEAR      =     2
    BICUBIC       =     4
    EXPERIMENT    =     8
    POINT         =  0x10 # nearest neighbour
    AREA          =  0x20
    BICUBLIN      =  0x40
    GAUSS         =  0x80
    SINC          = 0x100
    LANCZOS       = 0x200
    SPLINE        = 0x400

    fun get_context = sws_getContext(
      src_w : LibC::Int,
      src_h : LibC::Int,
      src_format : PixelFormat,
      dst_w : LibC::Int,
      dst_h : LibC::Int,
      dst_format : PixelFormat,
      flags : LibC::Int,
      src_filter : Void*,
      dst_filter : Void*,
      param : Void*
    ) : Context

    fun scale = sws_scale(
      c : Context,
      src_slice : UInt8**,
      src_stride : LibC::Int*,
      src_slicey : LibC::Int,
      src_sliceh : LibC::Int,
      dst_slice : UInt8**,
      dst_stride : LibC::Int*
    ) : LibC::Int

    fun free_context = sws_freeContext(sws_context : Context)
  end
end
