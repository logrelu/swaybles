// "My photos": the person's own pictures, framed like little polaroids and hung with the charms.
// The picture is copied (framed) into the photos folder and never read from its original place
// again; nothing about it leaves the Mac. Reading through ImageIO keeps iPhone photos the right
// way up (EXIF orientation) and scales in one step.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PhotoCharms {
    public static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Swaybles/Photos")
    }

    public static func load(folder: URL = defaultFolder) -> Catalog {
        (try? Catalog(folder: folder)) ?? Catalog(charms: [], folder: folder)
    }

    /// Frames the picture and adds it to the photos catalog. nil if the file isn't a readable image.
    public static func add(from url: URL, folder: URL = defaultFolder) -> (catalog: Catalog, charm: Charm)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let picture = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,   // honour EXIF orientation
                  kCGImageSourceThumbnailMaxPixelSize: 460,
              ] as CFDictionary),
              let framed = polaroid(picture) else { return nil }
        let id = "photo-" + UUID().uuidString.prefix(8).lowercased()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try writePNG(framed, to: folder.appendingPathComponent("\(id).png"))
        } catch { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        let charm = Charm(id: id, name: name.isEmpty ? "My photo" : name, pack: "my-photos",
                          theme: "My photos", file: "\(id).png",
                          w: Double(framed.width), h: Double(framed.height), ax: 0.5, ay: 0)
        return save(load(folder: folder).charms + [charm], folder: folder).map { ($0, charm) }
    }

    public static func remove(_ id: String, folder: URL = defaultFolder) -> Catalog {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(id).png"))
        return save(load(folder: folder).charms.filter { $0.id != id }, folder: folder)
            ?? Catalog(charms: [], folder: folder)
    }

    private static func save(_ charms: [Charm], folder: URL) -> Catalog? {
        guard let data = try? JSONEncoder().encode(charms),
              (try? data.write(to: folder.appendingPathComponent("charms.json"))) != nil else { return nil }
        return Catalog(charms: charms, folder: folder)
    }

    /// The picture on a warm-white card: even border, roomier at the bottom, rounded corners.
    private static func polaroid(_ picture: CGImage) -> CGImage? {
        guard picture.width > 0, picture.height > 0 else { return nil }
        let cw = Double(picture.width), ch = Double(picture.height)
        let side = 16.0, bottom = 44.0
        let w = Int(cw + side * 2), h = Int(ch + side + bottom)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let card = CGRect(x: 0, y: 0, width: Double(w), height: Double(h))
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.93, alpha: 1))
        ctx.fillPath()
        // CGContext's origin is the bottom-left, so the roomy edge goes under the picture.
        ctx.draw(picture, in: CGRect(x: side, y: bottom, width: cw, height: ch))
        return ctx.makeImage()
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
