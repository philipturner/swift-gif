import Foundation
import Logging
import Graphics
import Utils

fileprivate let log = Logger(label: "GIF.GIFEncoder")

/// Encodes an animated GIF to an in-memory byte buffer.
struct GIFEncoder {
    public private(set) var data: Data

    /// Creates a new GIF with the specified
    /// dimensions. A loop count of 0 means infinite
    /// loops.
    public init() {
        data = Data()
    }

    public mutating func append(gif: GIF) throws {
        // See http://giflib.sourceforge.net/whatsinagif/bits_and_bytes.html for a detailed explanation of the format
        appendHeader()
        append(logicalScreenDescriptor: gif.logicalScreenDescriptor)

        if let quantization = gif.globalQuantization {
            append(colorTable: quantization.colorTable)
        }

        for applicationExtension in gif.applicationExtensions {
            append(applicationExtension: applicationExtension)
        }

        for frame in gif.frames {
            append(frame: frame, globalQuantization: gif.globalQuantization)
        }

        appendTrailer()
    }

    private mutating func append(byte: UInt8) {
        data.append(byte)
    }

    private mutating func append(packedField: PackedFieldByte) {
        append(byte: packedField.rawValue)
    }

    private mutating func append(short: UInt16) {
        data.append(UInt8(short & 0xFF))
        data.append(UInt8((short >> 8) & 0xFF))
    }

    private mutating func append(string: String) {
        data.append(string.data(using: .utf8)!)
    }

    private mutating func appendHeader() {
        append(string: GIFConstants.header)
    }

    private mutating func append(logicalScreenDescriptor: LogicalScreenDescriptor) {
        append(short: logicalScreenDescriptor.width)
        append(short: logicalScreenDescriptor.height)

        var packedField = PackedFieldByte()
        packedField.append(logicalScreenDescriptor.useGlobalColorTable)
        packedField.append(logicalScreenDescriptor.colorResolution, bits: 3)
        packedField.append(logicalScreenDescriptor.sortFlag)
        packedField.append(logicalScreenDescriptor.sizeOfGlobalColorTable, bits: 3)
        append(packedField: packedField)

        append(byte: logicalScreenDescriptor.backgroundColorIndex)
        append(byte: logicalScreenDescriptor.pixelAspectRatio)
    }

    private mutating func append(applicationExtension: ApplicationExtension) {
        switch applicationExtension {
            case .looping(let loopCount):
                append(byte: 0x21) // Extension introducer
                append(byte: 0xFF) // Application extension
                append(byte: 0x0B) // Block size
                append(string: "NETSCAPE2.0")
                append(byte: 0x03) // Block size
                append(byte: 0x01) // Loop indicator
                append(short: loopCount)
                append(byte: 0x00) // Block terminator
        }
    }

    private mutating func append(graphicsControlExtension: GraphicsControlExtension) {
        append(byte: 0x21) // Extension introducer
        append(byte: 0xF9) // Graphics control label
        append(byte: 0x04) // Block size in bytes

        var packedField = PackedFieldByte()
        packedField.append(0, bits: 3)
        packedField.append(graphicsControlExtension.disposalMethod.rawValue, bits: 3)
        packedField.append(graphicsControlExtension.userInputFlag)
        packedField.append(graphicsControlExtension.transparentColorFlag)
        append(packedField: packedField)

        append(short: graphicsControlExtension.delayTime)
        append(byte: graphicsControlExtension.backgroundColorIndex) // Transparent color index
        append(byte: 0x00) // Block terminator
    }

    private mutating func append(imageDescriptor: ImageDescriptor) {
        append(byte: 0x2C) // Image separator
        append(short: imageDescriptor.imageLeft)
        append(short: imageDescriptor.imageTop)
        append(short: imageDescriptor.imageWidth)
        append(short: imageDescriptor.imageHeight)

        var packedField = PackedFieldByte()
        packedField.append(imageDescriptor.useLocalColorTable)
        packedField.append(imageDescriptor.interlaceFlag)
        packedField.append(imageDescriptor.sortFlag)
        packedField.append(0, bits: 2)
        packedField.append(imageDescriptor.sizeOfLocalColorTable, bits: 3)
        append(packedField: packedField)
    }

    private mutating func append(colorTable: [Color]) {
        log.debug("Appending color table...")
        let maxColorBytes = GIFConstants.colorCount * GIFConstants.colorChannels
        var i = 0

        for color in colorTable {
            append(byte: color.red)
            append(byte: color.green)
            append(byte: color.blue)
            i += GIFConstants.colorChannels
        }

        while i < maxColorBytes {
            append(byte: 0x00)
            i += 1
        }
    }

    private func quantize(color: Color, with quantization: ColorQuantization, backgroundColorIndex: Int) -> Int {
        if color.alpha < 128 {
            return backgroundColorIndex // Use transparent color
        } else {
            return quantization.quantize(color: color)
        }
    }

    private mutating func appendImageDataAsLZW(image: Image, quantization: ColorQuantization, width: Int, height: Int) {
        // Convert the ARGB-encoded image first to color
        // indices and then to LZW-compressed codes
        var encoder = LzwEncoder(colorCount: GIFConstants.colorCount)
        var lzwEncoded = BitData()

        log.debug("LZW-encoding the frame...")
        encoder.beginEncoding(into: &lzwEncoded)

        // Iterate all pixels as ARGB values and encode them
        for y in 0..<height {
            for x in 0..<width {
                encoder.encodeAndAppend(index: quantize(color: image[y, x], with: quantization, backgroundColorIndex: Int(GIFConstants.backgroundColorIndex)), into: &lzwEncoded)
            }
        }

        encoder.finishEncoding(into: &lzwEncoded)

        log.debug("Appending the encoded frame, minCodeSize: \(encoder.minCodeSize)...")
        append(byte: UInt8(encoder.minCodeSize))

        let lzwData = lzwEncoded.bytes
        var byteIndex = 0
        while byteIndex < lzwData.count {
            let subBlockByteCount = min(0xFF, lzwData.count - byteIndex)
            append(byte: UInt8(subBlockByteCount))
            for _ in 0..<subBlockByteCount {
                append(byte: lzwData[byteIndex])
                byteIndex += 1
            }
        }

        append(byte: 0x00) // Block terminator
    }

    /// Appends a frame with the specified quantizer
    /// and delay time (in hundrets of a second).
    private mutating func append(frame: Frame, globalQuantization: ColorQuantization? = nil) {
        let image = frame.image

        append(graphicsControlExtension: frame.graphicsControlExtension)
        append(imageDescriptor: frame.imageDescriptor)

        if let quantization = frame.localQuantization {
            append(colorTable: quantization.colorTable)
        }

        guard let quantization = frame.localQuantization ?? globalQuantization else { fatalError("No color quantization specified for GIF frame") }
        appendImageDataAsLZW(image: image, quantization: quantization, width: image.width, height: image.height)
    }

    private mutating func appendTrailer() {
        append(byte: GIFConstants.trailer)
    }
}
