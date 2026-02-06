import CFFmpegShim

/// A Swift wrapper around FFmpeg's `AVRational` (numerator/denominator pair).
public struct Rational: Sendable, Equatable, CustomStringConvertible {
    public var numerator: Int32
    public var denominator: Int32

    public init(numerator: Int32, denominator: Int32) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public init(_ avRational: AVRational) {
        self.numerator = avRational.num
        self.denominator = avRational.den
    }

    public var avRational: AVRational {
        AVRational(num: numerator, den: denominator)
    }

    /// The rational value as a Double.
    public var doubleValue: Double {
        guard denominator != 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }

    public var description: String {
        "\(numerator)/\(denominator)"
    }

    /// The FFmpeg time base constant (1/1000000).
    public static let timeBase = Rational(cffmpeg_AV_TIME_BASE_Q())

    /// Rescale a timestamp from one time base to another.
    public static func rescale(_ value: Int64, from src: Rational, to dst: Rational) -> Int64 {
        cffmpeg_av_rescale_q(value, src.avRational, dst.avRational)
    }
}
