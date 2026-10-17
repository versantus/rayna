import CoreGraphics
import XCTest
@testable import RaynaCore

final class BadgePixelsTests: XCTestCase {
    /// A 4×4 picture: opaque red top row, opaque blue bottom row, clear in between.
    private func picture() -> CGImage {
        var px = [UInt8](repeating: 0, count: 4 * 4 * 4)
        for x in 0..<4 {
            px[x * 4 + 0] = 255; px[x * 4 + 3] = 255                    // row 0 (top): red
            px[(12 + x) * 4 + 2] = 255; px[(12 + x) * 4 + 3] = 255      // row 3 (bottom): blue
        }
        let provider = CGDataProvider(data: Data(px) as CFData)!
        return CGImage(width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 16,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    func testCropKeepsTheBadgeTheRightWayUp() {
        let cut = BadgePixels.crop(picture())!
        let data = cut.dataProvider!.data! as Data
        let bpr = cut.bytesPerRow
        XCTAssertEqual(cut.height, 4)
        XCTAssertEqual(data[0], 255, "top row should still be red")
        XCTAssertEqual(data[(cut.height - 1) * bpr + 2], 255, "bottom row should still be blue")
    }
}
