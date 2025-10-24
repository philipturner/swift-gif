extension RandomAccessCollection {
    func truncated(to length: Int, appending appended: Element? = nil) -> [Element] {
        if count > length {
            return appended.map { prefix(length - 1) + [$0] } ?? Array(prefix(length))
        } else {
            return Array(self)
        }
    }
}
