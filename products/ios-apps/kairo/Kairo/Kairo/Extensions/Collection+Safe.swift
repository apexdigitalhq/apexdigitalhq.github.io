import Foundation

extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {

    /// Returns the last N elements of the array.
    func takeLast(_ n: Int) -> [Element] {
        let startIndex = Swift.max(0, count - n)
        return Array(self[startIndex...])
    }
}

extension Sequence where Element: Numeric {

    /// Returns the sum of all elements.
    func sum() -> Element {
        reduce(0, +)
    }
}

extension Sequence where Element: BinaryFloatingPoint {

    /// Returns the average of all elements, or nil if empty.
    func average() -> Element? {
        var count: Element = 0
        var total: Element = 0
        for element in self {
            total += element
            count += 1
        }
        guard count > 0 else { return nil }
        return total / count
    }
}
