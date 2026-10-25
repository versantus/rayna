// Prints the CGWindowID of the Connect IQ simulator's main window (for screencapture -l).
import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let sims = list.filter { ($0[kCGWindowOwnerName as String] as? String)?.lowercased().contains("simulator") == true
    && (($0[kCGWindowLayer as String] as? Int) ?? 1) == 0 }
let best = sims.max { a, b in
    let ra = (a[kCGWindowBounds as String] as? [String: CGFloat]) ?? [:], rb = (b[kCGWindowBounds as String] as? [String: CGFloat]) ?? [:]
    return (ra["Width"] ?? 0) * (ra["Height"] ?? 0) < (rb["Width"] ?? 0) * (rb["Height"] ?? 0)
}
if let id = best?[kCGWindowNumber as String] as? Int { print(id) } else { exit(1) }
