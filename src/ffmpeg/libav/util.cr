require "../libav"

module FFmpeg::LibAV
  @[Link("avutil")]
  lib Util
    AV_NUM_DATA_POINTERS = 8

    struct AVFrame
      data : UInt8*[8]
      linesize : LibC::Int[8]
      extended_data : Void*
      width : LibC::Int
      height : LibC::Int
      nb_samples : LibC::Int
      format : PixelFormat
      key_frame : LibC::Int
    end

    fun version_info = av_version_info : LibC::Char*
    fun frame_alloc = av_frame_alloc : AVFrame*
    fun frame_free = av_frame_free(frame : AVFrame**)
    fun image_buffer_size = av_image_get_buffer_size(pix_fmt : PixelFormat, width : LibC::Int, height : LibC::Int, align : LibC::Int) : LibC::Int
  end
end
