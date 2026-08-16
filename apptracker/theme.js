.pragma library

// Everforest, matched to surface-dots/.config/quickshell/theme.js so the
// widget does not look like a guest on the desktop. Kept as a local copy
// rather than an import, so this config runs standalone.

var bgPanel = "rgba(20,23,25,0.94)"
var bgCard  = "#1e2326"
var bgItem  = "#2d353b"
var bgItemHover = "#374145"
var bgInput = "#232a2e"

var fgMain  = "#E5DFC5"
var fgMuted = "#9da9a0"
var fgOnAccent = "#232a2e"

var accent     = "#a7c080"   // green
var accentBlue = "#7fbbb3"
var accentRed  = "#e67e80"
var accentGold = "#dbbc7f"
var accentGrey = "#859289"

// Status -> colour. Semantic, deliberately separate from the accent.
function statusColor(status) {
    switch (status) {
    case "drafting":  return accentGold
    case "submitted": return accentBlue
    case "test":      return accentBlue
    case "interview": return accent
    case "offer":     return accent
    case "rejected":  return accentRed
    case "closed":    return accentGrey
    default:          return accentGrey
    }
}

var statuses = ["drafting", "submitted", "test", "interview", "offer", "rejected", "closed"]

// Sizing
var radiusOuter = 24
var radiusInner = 16
var radiusChip  = 999

var padCard = 12
var gapCard = 10

// Fonts
var textFont = "Manrope"
var monoFont = "JetBrainsMono Nerd Font"
var iconFont = "JetBrainsMono Nerd Font"
