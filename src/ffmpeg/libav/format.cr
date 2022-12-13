require "../libav"

module FFmpeg::LibAV
  @[Link("avformat")]
  lib Format
    fun network_init = avformat_network_init : LibC::Int
    fun network_deinit = avformat_network_deinit : LibC::Int

    fun alloc_context = avformat_alloc_context : Context*

    fun open_input = avformat_open_input(
      ps : Context**,
      filename : LibC::Char*,
      fmt : Void*,    # AVInputFormat
      options : Void* # AVDictionary** (single pointer so we can easily pass null)
    ) : LibC::Int
    fun close_input = avformat_close_input(s : Context**)

    fun find_stream_info = avformat_find_stream_info(
      ic : Context*,
      options : Void* # AVDictionary**
    ) : LibC::Int

    fun get_video_codec = av_format_get_video_codec(
      ic : Context*
    ) : Codec::AVCodec

    fun read_frame = av_read_frame(
      s : Context*,
      pkt : Codec::Packet*
    ) : LibC::Int

    fun alloc_io_context = avio_alloc_context(
      buffer : UInt8*,
      buffer_size : LibC::Int,
      write_flag : LibC::Int,
      opaque : Void*,
      read_packet : (Void*, UInt8*, LibC::Int -> LibC::Int),
      write_packet : (Void*, UInt8*, LibC::Int -> LibC::Int),
      seek : (Void*, LibC::Long, LibC::Int -> LibC::Long)
    ) : IOContext

    type IOContext = Void*

    # http://ffmpeg.org/doxygen/trunk/structAVFormatContext.html
    struct Context
      av_class : Void*
      iformat : Void*
      oformat : Void*
      priv_data : Void*
      pb : IOContext # AVIOContext == used for IO callbacks
      ctx_flags : LibC::Int
      nb_streams : LibC::UInt
      streams : AVStream**
    end

    struct AVStream
      index : LibC::Int
      id : LibC::Int
      codec : Codec::Context*
      priv_data : Void*
      time_base : Codec::Rational
      start_time : LibC::Long
      duration : LibC::Long
      nb_frames : LibC::Long
      disposition : LibC::Int
      discard : Discard
      sample_aspect_ratio : Codec::Rational
      metadata : Void*
      avg_frame_rate : Codec::Rational
      attached_pic : Codec::Packet
      side_data : Void*
      nb_side_data : LibC::Int
      event_flags : LibC::Int
      r_frame_rate : Codec::Rational
      recommended_encoder_configuration : LibC::Char*
      codecpar : Codec::AVCodecParameters
    end
  end
end
