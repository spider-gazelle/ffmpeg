require "../libav"

module FFmpeg::LibAV
  @[Link("avutil")]
  lib Util
    AV_NUM_DATA_POINTERS = 8

    # https://ffmpeg.org//doxygen/trunk/frame_8h_source.html
    struct AVFrame
      data : UInt8*[8]
      linesize : LibC::Int[8]
      extended_data : Void*
      width : LibC::Int
      height : LibC::Int
      nb_samples : LibC::Int
      format : PixelFormat
    end

    fun version_info = av_version_info : LibC::Char*
    fun frame_alloc = av_frame_alloc : AVFrame*
    fun frame_clone = av_frame_clone(frame : AVFrame*) : AVFrame*
    fun frame_copy = av_frame_copy(dst : AVFrame*, src : AVFrame*) : LibC::Int
    fun frame_free = av_frame_free(frame : AVFrame**)
    fun image_buffer_size = av_image_get_buffer_size(pix_fmt : PixelFormat, width : LibC::Int, height : LibC::Int, align : LibC::Int) : LibC::Int
    fun image_fill_linesizes = av_image_fill_linesizes(linesizes : LibC::Int*, pix_fmt : PixelFormat, width : LibC::Int) : LibC::Int
    fun image_fill_arrays = av_image_fill_arrays(dst_data : UInt8**, linesizes : LibC::Int*, img_buffer : UInt8*, pix_fmt : PixelFormat, width : LibC::Int, height : LibC::Int, align : LibC::Int) : LibC::Int

    fun seek_frame = av_seek_frame(frame : Format::Context*, stream_index : LibC::Int, timestamp : LibC::Int64T, flags : LibC::Int) : LibC::Int
    fun strerror = av_strerror(errnum : LibC::Int, errbuf : UInt8*, errbuf_size : LibC::SizeT) : LibC::Int
  end
end
