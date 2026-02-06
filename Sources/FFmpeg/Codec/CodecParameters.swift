import CFFmpegShim

/// Utilities for working with `AVCodecParameters`.
public enum CodecParameters {
    /// Copies parameters from one `AVCodecParameters` to another.
    public static func copy(
        from src: UnsafeMutablePointer<AVCodecParameters>,
        to dst: UnsafeMutablePointer<AVCodecParameters>
    ) throws {
        try ffCheck(avcodec_parameters_copy(dst, src))
    }
}
