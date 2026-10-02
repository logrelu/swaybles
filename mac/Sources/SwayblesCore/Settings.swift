// Everything the person chooses, saved locally (UserDefaults, as JSON). Nothing leaves the Mac.
import Foundation

public enum RopeStyle: String, Codable, CaseIterable, Identifiable {
    case goldThread = "gold-thread", silverChain = "silver-chain", goldChain = "gold-chain",
         leather, velvet, twine, pearls, rainbow

    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .goldThread: return "Golden Thread"
        case .silverChain: return "Silver Chain"
        case .goldChain: return "Gold Chain"
        case .leather: return "Leather Cord"
        case .velvet: return "Velvet Braid"
        case .twine: return "Garden Twine"
        case .pearls: return "Pearl Strand"
        case .rainbow: return "Rainbow Cord"
        }
    }
}

/// One charm hanging on screen.
public struct PlacedCharm: Codable, Equatable, Identifiable {
    public var uid: String
    public var charmID: String
    public var x: Double        // where the pin sits, as a fraction of screen width
    public var length: Double   // rope length in points

    public var id: String { uid }

    public init(uid: String = UUID().uuidString, charmID: String, x: Double, length: Double) {
        self.uid = uid; self.charmID = charmID; self.x = x; self.length = length
    }
}

public struct Settings: Codable, Equatable {
    public var charms: [PlacedCharm] = []
    public var size = 1.0
    public var rope = RopeStyle.goldThread
    public var breeze = false
    public var sound = true
    public var calmer = false              // extra-calm swinging on top of the system Reduce Motion
    public var still = false               // no swinging at all: charms hang quietly
    public var focusMinutes = 25
    public var idleMinutes = 5
    public var showYearCountdown = false   // Banner Bat shows "92 days left in 2026" instead of "Day N / 90"
    public var ninety: NinetyDays?
    public var wins = WinsJar()
    public var hidden = false

    public init() {}

    // Tolerant decoding: a field added in a later version must not wipe someone's settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        charms = (try? c.decodeIfPresent([PlacedCharm].self, forKey: .charms)) ?? d.charms
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? d.size
        rope = (try? c.decodeIfPresent(RopeStyle.self, forKey: .rope)) ?? d.rope
        breeze = try c.decodeIfPresent(Bool.self, forKey: .breeze) ?? d.breeze
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        calmer = try c.decodeIfPresent(Bool.self, forKey: .calmer) ?? d.calmer
        still = try c.decodeIfPresent(Bool.self, forKey: .still) ?? d.still
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        idleMinutes = try c.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? d.idleMinutes
        showYearCountdown = try c.decodeIfPresent(Bool.self, forKey: .showYearCountdown) ?? d.showYearCountdown
        ninety = (try? c.decodeIfPresent(NinetyDays.self, forKey: .ninety)) ?? nil
        wins = (try? c.decodeIfPresent(WinsJar.self, forKey: .wins)) ?? d.wins
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? d.hidden
    }

    /// First launch: just Boo (or the first installed charm) — one friendly face, not a crowd.
    /// People hang more from the Studio when they're ready.
    public static func firstLaunch(catalog: Catalog) -> Settings {
        let preferred = ["boo", "timer-ghost", "skeleton", "banner-bat", "cloud-lamb", "task-lantern",
                         "flower-skull", "chalkboard-cat", "sprout-bean", "cauldron", "rip-mondays"]
        var ids = preferred.filter { catalog.charm($0) != nil }
        if ids.isEmpty { ids = catalog.charms.map(\.id) }
        ids = Array(ids.prefix(1))
        let lengths = [160.0, 100, 190, 120, 150]
        var s = Settings()
        s.charms = ids.enumerated().map { i, id in
            let x = ids.count == 1 ? 0.6 : 0.34 + 0.52 * Double(i) / Double(ids.count - 1)
            return PlacedCharm(charmID: id, x: x, length: lengths[i % lengths.count])
        }
        return s
    }
}
