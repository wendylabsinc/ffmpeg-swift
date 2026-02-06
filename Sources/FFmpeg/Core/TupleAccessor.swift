/// Provides indexing into C fixed-size array tuples (e.g., `AVFrame.data` which
/// is imported as a tuple of 8 pointers).
///
/// Usage:
/// ```swift
/// let ptr = withUnsafePointer(to: &frame.pointee.data) { tuplePtr in
///     tupleElement(tuplePtr, index: 0, as: UnsafeMutablePointer<UInt8>?.self)
/// }
/// ```
public func tupleElement<Tuple, Element>(
    _ tuple: UnsafePointer<Tuple>,
    index: Int,
    as type: Element.Type
) -> Element {
    tuple.withMemoryRebound(to: type, capacity: MemoryLayout<Tuple>.size / MemoryLayout<Element>.size) { base in
        base[index]
    }
}

/// Mutable variant of `tupleElement`.
public func tupleElement<Tuple, Element>(
    _ tuple: UnsafeMutablePointer<Tuple>,
    index: Int,
    as type: Element.Type
) -> Element {
    tuple.withMemoryRebound(to: type, capacity: MemoryLayout<Tuple>.size / MemoryLayout<Element>.size) { base in
        base[index]
    }
}

/// Sets a value at the given index in a C fixed-size array tuple.
public func setTupleElement<Tuple, Element>(
    _ tuple: UnsafeMutablePointer<Tuple>,
    index: Int,
    value: Element
) {
    tuple.withMemoryRebound(to: Element.self, capacity: MemoryLayout<Tuple>.size / MemoryLayout<Element>.size) { base in
        base[index] = value
    }
}
