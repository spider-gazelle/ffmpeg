require "../libav"

module FFmpeg::LibAV
  @[Link("avcodec")]
  lib Codec
    fun configuration = avcodec_configuration : LibC::Char*
    fun version = avcodec_version : LibC::UInt

    # deprecated in ffmpeg 4: https://github.com/leandromoreira/ffmpeg-libav-tutorial/issues/29
    # fun register_all = avcodec_register_all

    fun dump_format = av_dump_format(
      ic : Format::Context*,
      index : LibC::Int,
      filename : LibC::Char*,
      is_output : LibC::Int
    )

    fun find_best_stream = av_find_best_stream(
      ic : Format::Context*,
      media_type : MediaType,
      wanted_stream_nb : LibC::Int,
      related_stream : LibC::Int,
      decoder_ret : Void*, # AVCodec**
      flags : LibC::Int
    ) : LibC::Int

    fun packet_unref = av_packet_unref(pkt : Packet*)

    type AVCodec = Void*
    # type Context = Void*
    type AVCodecParameters = Void*

    struct Context
      av_class : Void*
      log_level_offset : LibC::Int
      codec_type : MediaType
      codec : AVCodec
      codec_id : LibC::Int
      codec_tag : LibC::UInt
      stream_codec_tag : LibC::UInt
      priv_data : Void*
      internal : Void*
      opaque : Void*
      bit_rate : LibC::Int64T
      bit_rate_tolerance : LibC::Int
      global_quality : LibC::Int
      compression_level : LibC::Int
      flags : LibC::Int
      flags2 : LibC::Int
      extradata : LibC::UInt8T*
      extradata_size : LibC::Int
      time_base : Rational
      ticks_per_frame : LibC::Int
      delay : LibC::Int
      width : LibC::Int
      height : LibC::Int
      coded_width : LibC::Int
      coded_height : LibC::Int
      gop_size : LibC::Int
      pix_fmt : PixelFormat
    end

    struct Rational
      num : LibC::Int
      den : LibC::Int
    end

    struct Packet
      buf : Void*
      pts : LibC::Long
      dts : LibC::Long
      data : LibC::UChar*
      size : LibC::Int
      stream_index : LibC::Int
      flags : LibC::Int
      side_data : Void*
      side_data_elems : LibC::Int
      duration : LibC::Long
      pos : LibC::Long
      convergence_duration : LibC::Long
    end

    # https://ffmpeg4d.dpldocs.info/ffmpeg.libavcodec.avcodec.avcodec_open2.html
    fun open2 = avcodec_open2(
      avctx : Context*,
      codec : AVCodec,
      options : Void* # AVDictionary**
    ) : LibC::Int

    # https://ffmpeg4d.dpldocs.info/ffmpeg.libavcodec.avcodec.avcodec_send_packet.html
    fun send_packet = avcodec_send_packet(
      avctx : Context*,
      avpkt : Packet*
    ) : LibC::Int

    # https://ffmpeg4d.dpldocs.info/ffmpeg.libavcodec.avcodec.avcodec_receive_frame.html
    fun receive_frame = avcodec_receive_frame(
      avctx : Context*,
      frame : Util::AVFrame*
    ) : LibC::Int

    # Free the codec context and everything associated with it and write NULL to the provided pointer.
    fun alloc_context = avcodec_alloc_context3(codec : AVCodec) : Context*
    fun free_context = avcodec_free_context(avctx : Context**)

    fun alloc_parameters = avcodec_parameters_alloc : AVCodecParameters
    fun free_parameters = avcodec_parameters_free(par : AVCodecParameters*)

    fun packet_alloc = av_packet_alloc : Packet*
    fun packet_free = av_packet_free(Packet**)

    # sets packet options to default values (does not allocate buffer)
    # already called by av_packet_alloc, so only required if struct is initialized in crystal
    fun init_packet = av_init_packet(Packet*)

    fun parameters_to_context = avcodec_parameters_to_context(
      codec : Context*,
      par : AVCodecParameters
    ) : LibC::Int

    fun parameters_from_context = avcodec_parameters_from_context(
      par : AVCodecParameters,
      codec : Context*
    ) : LibC::Int

    fun find_decoder = avcodec_find_decoder(codec_id : LibC::Int) : AVCodec
    fun flush_buffers = avcodec_flush_buffers(codec : Context*)
  end
end
