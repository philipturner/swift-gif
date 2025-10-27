import XCTest
import Logging
@testable import GIFModule

fileprivate let log = Logger(label: "GIFTests.GIFCoderTests")

final class GIFCoderTests: XCTestCase {
    override func setUp() {
        XCTAssert(isLoggingConfigured)
    }

    func testGIFCoder() throws {
        for resource in ["mini", "mandelbrot"] {
            log.info("Testing GIF en-/decoder with \(resource).gif...")

            let url = Bundle.module.url(forResource: resource, withExtension: "gif")!
            let data = try Data(contentsOf: url)
            let gif = try GIF(data: data) // Try decoding the GIF
            let reEncoded = try gif.encoded() // Try encoding it again
            let reDecoded = try GIF(data: reEncoded) // Try decoding it again

            for (frame1, frame2) in zip(gif.frames, reDecoded.frames) {
                assertImagesEqual(frame1.image, frame2.image)
                XCTAssertEqual(frame1.delayTime, frame2.delayTime)
            }
        }
    }
    
    // Make sure the snippet on the README works without crashing. This
    // adds ~0.8 seconds to the test suite's execution time, on a system where
    // it was taking ~14.0 seconds before.
    func testSnippet() throws {
        // Create a new GIF
        var gif = GIF(width: 300, height: 300)
        
        // Add some frames for the animation
        for i in 0..<20 {
            var image = Image(width: 300, height: 300)
            for y in 0..<300 {
                for x in 0..<300 {
                    // Generate pixel data
                    let color = Color(
                        red: UInt8(x % 256),
                        green: UInt8(x % 256),
                        blue: UInt8((i * 20) % 256))
                    image[y, x] = color
                }
            }
            gif.frames.append(.init(image: image, delayTime: 100))
        }
        
        // Encode the GIF to a byte buffer
        let data = try gif.encoded()
        
        // Suppress warnings about otherwise valid code in the snippet.
        _ = data
    }

    private func assertImagesEqual(_ image1: Image, _ image2: Image) {
        XCTAssertEqual(image1.width, image2.width)
        XCTAssertEqual(image1.height, image2.height)

        for y in 0..<image1.height {
            for x in 0..<image1.width {
                let color1 = image1[y, x]
                let color2 = image2[y, x]

                // Only assert equality on fully non-transparent
                // pixels since these not affected by GIFs (potentially
                // lossy) encoding of transparent pixels.
                if color1.alpha == 255 && color2.alpha == 255 {
                    XCTAssertEqual(color1, color2)
                }
            }
        }
    }
}
