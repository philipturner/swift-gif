# GIF Coder for Swift

[![Build](https://github.com/fwcd/swift-gif/actions/workflows/build.yml/badge.svg)](https://github.com/fwcd/swift-gif/actions/workflows/build.yml)
[![Docs](https://github.com/fwcd/swift-gif/actions/workflows/docs.yml/badge.svg)](https://fwcd.github.io/swift-gif/documentation/gif)

A lightweight LZW encoder and decoder for animated GIFs written in pure Swift, thus running on any platform, including Linux.

## Example

```swift
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
```

## Technical Details

GIF encoding is more computationally intensive than decoding. It can become a bottleneck when GIF is used as a video codec and serialization must happen in real-time. Therefore, multicore CPU is used to accelerate the encoding of animated GIFs. All the animation frames are gathered into one `Array`, which is then divided among all CPU cores in the system.

## System Dependencies

* Swift 5.10+
