// The charm catalog: Resources/Charms/charms.json, written by `npm run charms`.
import Foundation

public struct Charm: Codable, Equatable, Identifiable {
    /// Where on the image the app may write (a blank clock face, chalkboard, banner, tag).
    public struct Label: Codable, Equatable {
        public var x: Double, y: Double, w: Double, h: Double   // fractions of the image
        public var shape: String                                 // "rect" or "circle"
    }

    /// What a Focus Crew charm shows. Ordinary charms have no role.
    public enum Role: String, Codable {
        case timer, quote, banner, task, `break`
    }

    public var id: String
    public var name: String
    public var pack: String
    public var theme: String
    public var file: String        // e.g. "charms/spooky-crew/skeleton.png" (relative to the Charms folder's parent)
    public var w: Double           // image size in pixels
    public var h: Double
    public var ax: Double          // where the rope attaches, as fractions of w and h
    public var ay: Double
    public var role: Role?
    public var label: Label?

    public init(id: String, name: String, pack: String, theme: String, file: String,
                w: Double, h: Double, ax: Double, ay: Double, role: Role? = nil, label: Label? = nil) {
        self.id = id; self.name = name; self.pack = pack; self.theme = theme; self.file = file
        self.w = w; self.h = h; self.ax = ax; self.ay = ay; self.role = role; self.label = label
    }

    /// Path of the image relative to the Charms folder ("spooky-crew/skeleton.png").
    public var relativePath: String {
        file.hasPrefix("charms/") ? String(file.dropFirst("charms/".count)) : file
    }
}

public struct Catalog {
    public let charms: [Charm]
    public let folder: URL

    public init(charms: [Charm], folder: URL) {
        self.charms = charms
        self.folder = folder
    }

    /// Loads `charms.json` from a Charms folder. Charms whose image is missing are skipped.
    public init(folder: URL) throws {
        let data = try Data(contentsOf: folder.appendingPathComponent("charms.json"))
        let all = try JSONDecoder().decode([Charm].self, from: data)
        self.folder = folder
        self.charms = all.filter {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.relativePath).path)
        }
    }

    public func charm(_ id: String) -> Charm? { charms.first { $0.id == id } }
    public func imageURL(for charm: Charm) -> URL { folder.appendingPathComponent(charm.relativePath) }
    public func charm(withRole role: Charm.Role) -> Charm? { charms.first { $0.role == role } }

    public struct Pack: Identifiable {
        public let id: String
        public let name: String
        public let charms: [Charm]
    }

    /// Packs in catalog order.
    public var packs: [Pack] {
        var order: [String] = []
        var byPack: [String: [Charm]] = [:]
        for c in charms {
            if byPack[c.pack] == nil { order.append(c.pack) }
            byPack[c.pack, default: []].append(c)
        }
        return order.map { Pack(id: $0, name: byPack[$0]![0].theme, charms: byPack[$0]!) }
    }
}
