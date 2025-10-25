// Chose BufferedImage instead of Image because the latter is too generic and
// likely to cause name conflicts. Resolving them with the library prefix
// ('GIF.Image' vs 'OtherLibrary.Image') creates more confusion because now
// Image could be a sub-type of the 'GIF' data type. A solution to that would
// be renaming this entire package to 'GIFModule'.

/// An image with an internal backing buffer.
public struct BufferedImage {
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
