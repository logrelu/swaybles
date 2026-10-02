import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SwayblesCore

@Suite struct PhotoCharmsTests {
    /// A fresh temp folder per test, so the real photo library is never touched.
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("swaybles-tests-\(UUID().uuidString)")

    func makeImage(w: Int, h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func write(_ image: CGImage, name: String, type: UTType = .jpeg, orientation: Int? = nil) -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        let props = orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(dest, image, props)
        CGImageDestinationFinalize(dest)
        return url
    }

    @Test func addFramesAndScales() throws {
        let url = write(makeImage(w: 800, h: 600), name: "holiday.jpg")
        let (cat, charm) = try #require(PhotoCharms.add(from: url, folder: folder))
        // 800x600 → content 460x345, plus 16 px sides and top, 44 px bottom.
        #expect(charm.w == 492 && charm.h == 405)
        #expect(charm.ax == 0.5 && charm.ay == 0)          // hangs from the top centre
        #expect(charm.name == "holiday" && charm.role == nil)
        #expect(cat.charm(charm.id) != nil)
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(charm.file).path))
    }

    @Test func smallPicturesAreNotBlownUp() throws {
        let url = write(makeImage(w: 100, h: 80), name: "tiny.png", type: .png)
        let (_, charm) = try #require(PhotoCharms.add(from: url, folder: folder))
        #expect(charm.w == 132 && charm.h == 140)          // 100x80 content, just framed
    }

    @Test func sidewaysPhoneShotsComeOutUpright() throws {
        // EXIF orientation 6: stored landscape, meant to be shown portrait (like most phone photos).
        let url = write(makeImage(w: 80, h: 60), name: "phone.jpg", orientation: 6)
        let (_, charm) = try #require(PhotoCharms.add(from: url, folder: folder))
        #expect(charm.w < charm.h, "photo should be portrait after the EXIF turn")
        #expect(charm.w == 92 && charm.h == 140)           // 60x80 content after the turn
    }

    @Test func photosSurviveARelaunch() throws {
        let url = write(makeImage(w: 200, h: 200), name: "keeper.jpg")
        let (_, charm) = try #require(PhotoCharms.add(from: url, folder: folder))
        let reloaded = PhotoCharms.load(folder: folder)    // as the app does at startup
        #expect(reloaded.charms.map(\.id) == [charm.id])
    }

    @Test func removeCleansUpFileAndCatalog() throws {
        let url = write(makeImage(w: 200, h: 200), name: "bye.jpg")
        let (_, charm) = try #require(PhotoCharms.add(from: url, folder: folder))
        let after = PhotoCharms.remove(charm.id, folder: folder)
        #expect(after.charms.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(charm.file).path))
        #expect(PhotoCharms.load(folder: folder).charms.isEmpty)
    }

    @Test func notAPictureIsRefusedGently() throws {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("letter.png")
        try "dear diary".data(using: .utf8)!.write(to: url)
        #expect(PhotoCharms.add(from: url, folder: folder) == nil)
        #expect(PhotoCharms.add(from: folder.appendingPathComponent("not-there.png"), folder: folder) == nil)
    }

    @Test func twoAddsTwoCharms() throws {
        let url = write(makeImage(w: 150, h: 150), name: "twin.jpg")
        let first = try #require(PhotoCharms.add(from: url, folder: folder))
        let second = try #require(PhotoCharms.add(from: url, folder: folder))
        #expect(first.charm.id != second.charm.id)
        #expect(second.catalog.charms.count == 2)
    }
}
