public struct Image {
    public let width: Int
    public let height: Int
    private var pixels: [UInt32]
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt32](repeating: .zero, count: width * height)
    }
    
    public subscript(_ y: Int, _ x: Int) -> Color {
        get {
            let address = y * width + x
            let rawValue = pixels[address]
            return Color(rgb: rawValue)
        }
        set {
            let address = y * width + x
            let rawValue = newValue.rgb
            pixels[address] = rawValue
        }
    }
}
