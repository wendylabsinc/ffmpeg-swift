import CFFmpegShim

/// Codec discovery utilities.
public enum Codec {
    /// Finds a decoder by codec ID.
    public static func findDecoder(id: CodecID) throws -> CodecRef {
        guard let codec = avcodec_find_decoder(id.avValue) else {
            throw FFmpegError.decoderNotFound
        }
        return CodecRef(codec)
    }

    /// Finds a decoder by name (e.g. "h264", "aac").
    public static func findDecoder(name: String) throws -> CodecRef {
        guard let codec = avcodec_find_decoder_by_name(name) else {
            throw FFmpegError.decoderNotFound
        }
        return CodecRef(codec)
    }

    /// Finds an encoder by codec ID.
    public static func findEncoder(id: CodecID) throws -> CodecRef {
        guard let codec = avcodec_find_encoder(id.avValue) else {
            throw FFmpegError.encoderNotFound
        }
        return CodecRef(codec)
    }

    /// Finds an encoder by name (e.g. "libx264", "aac").
    public static func findEncoder(name: String) throws -> CodecRef {
        guard let codec = avcodec_find_encoder_by_name(name) else {
            throw FFmpegError.encoderNotFound
        }
        return CodecRef(codec)
    }
}
