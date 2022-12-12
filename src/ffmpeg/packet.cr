require "../ffmpeg"

class FFmpeg::Packet
  def initialize(buffer_size : Int)
    @buffer = Bytes.new(buffer_size)
    @packet = LibAV::Codec.packet_alloc
    raise "failed to allocate context" if @packet.null?
    @packet_pointer = pointerof(@packet)

    @packet.value.data = @buffer.to_unsafe
    @packet.value.size = @buffer.size
  end

  @packet_pointer : Pointer(Pointer(LibAV::Codec::Packet))
  @packet : Pointer(LibAV::Codec::Packet)
  @buffer : Bytes

  def finalize
    LibAV::Codec.packet_free(@packet_pointer)
  end

  def to_unsafe
    @packet
  end

  def stream_index
    @packet.value.stream_index
  end
end
