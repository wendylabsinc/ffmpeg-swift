import CFFmpegShim

/// A safe wrapper around FFmpeg's `AVDictionary`.
public final class AVDictionaryWrapper: @unchecked Sendable {
    var pointer: OpaquePointer?

    /// Creates an empty dictionary.
    public init() {
        self.pointer = nil
    }

    deinit {
        av_dict_free(&pointer)
    }

    /// Sets a key-value pair. Overwrites existing entries.
    public func set(key: String, value: String) {
        av_dict_set(&pointer, key, value, 0)
    }

    /// Gets the value for a given key, or `nil` if not found.
    public func get(key: String) -> String? {
        guard let entry = av_dict_get(pointer, key, nil, 0) else { return nil }
        guard let val = entry.pointee.value else { return nil }
        return String(cString: val)
    }

    /// Returns the number of entries.
    public var count: Int32 {
        av_dict_count(pointer)
    }

    /// Returns all entries as a Swift dictionary.
    public var allEntries: [String: String] {
        var result: [String: String] = [:]
        var entry: UnsafePointer<AVDictionaryEntry>? = nil
        while true {
            entry = av_dict_iterate(pointer, entry)
            guard let e = entry else { break }
            let key = String(cString: e.pointee.key)
            let value = String(cString: e.pointee.value)
            result[key] = value
        }
        return result
    }
}
