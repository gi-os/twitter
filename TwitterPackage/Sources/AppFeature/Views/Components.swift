import SwiftUI
import XAPI

struct Avatar: View {
  let url: URL?
  let isSquare: Bool
  let size: CGFloat

  init(user: XUser, size: CGFloat) {
    url = user.avatarURL(forSize: size)
    isSquare = user.hasSquareAvatar
    self.size = size
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: isSquare ? size / 5 : size / 2, style: .continuous)
    AsyncImage(url: url) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      shape.fill(.quaternary)
    }
    .frame(width: size, height: size)
    .clipShape(shape)
    .accessibilityHidden(true)
  }
}

struct AuthorLine: View {
  let date: Date?
  let isVerified: Bool
  let name: String
  let screenName: String

  init(user: XUser, date: Date?) {
    self.date = date
    isVerified = user.isVerified
    name = user.name
    screenName = user.screenName
  }

  var body: some View {
    HStack(spacing: 4) {
      Text(name)
        .fontWeight(.bold)
        .lineLimit(1)
        .layoutPriority(1)
      if isVerified {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(.tint)
          .imageScale(.small)
          .accessibilityLabel("Verified")
      }
      Text(verbatim: "@\(screenName)")
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if let date {
        Text(verbatim: "·").foregroundStyle(.secondary)
        Text(date.shortRelative)
          .foregroundStyle(.secondary)
          .fixedSize()
      }
    }
    .font(.subheadline)
  }
}

struct TweetText: View {
  let links: [String: URL]
  let text: String
  var font: Font = .body

  var body: some View {
    Text(TweetText.attributed(text, links: links))
      .font(font)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  @MainActor private static var cache: [Int: AttributedString] = [:]

  @MainActor static func attributed(_ text: String, links: [String: URL]) -> AttributedString {
    var hasher = Hasher()
    hasher.combine(text)
    for key in links.keys.sorted() { hasher.combine(key) }
    let key = hasher.finalize()
    if let hit = cache[key] { return hit }
    let value = build(text, links: links)
    if cache.count > 4_000 { cache.removeAll(keepingCapacity: true) }
    cache[key] = value
    return value
  }

  private static func build(_ text: String, links: [String: URL]) -> AttributedString {
    let urlPatterns = links.keys.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:))
    let patterns = urlPatterns + [#"(?<![\w@])@\w{1,15}"#, #"(?<![\w&])#\w+"#, #"(?<![\w])\$[A-Za-z]{1,6}\b"#]
    guard let regex = try? NSRegularExpression(pattern: patterns.map { "(?:\($0))" }.joined(separator: "|"))
    else { return AttributedString(text) }

    var result = AttributedString()
    var cursor = text.startIndex
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let range = Range(match.range, in: text) else { continue }
      if cursor < range.lowerBound { result += AttributedString(text[cursor..<range.lowerBound]) }
      let token = String(text[range])
      var piece = AttributedString(token)
      piece.link = destination(for: token, links: links)
      result += piece
      cursor = range.upperBound
    }
    if cursor < text.endIndex { result += AttributedString(text[cursor...]) }
    return result
  }

  private static func destination(for token: String, links: [String: URL]) -> URL? {
    if let url = links[token] { return url }
    var components = URLComponents()
    components.scheme = Route.scheme
    if token.hasPrefix("@") {
      components.host = "user"
      components.path = "/\(token.dropFirst())"
    } else {
      components.host = "search"
      components.queryItems = [URLQueryItem(name: "q", value: token)]
    }
    return components.url
  }
}

struct EngagementButton: View {
  let action: () -> Void
  var activeColor: Color = .accentColor
  var activeSymbol: String?
  var count: Int?
  var isActive = false
  let label: LocalizedStringKey
  let symbol: String

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: isActive ? activeSymbol ?? symbol : symbol)
          .contentTransition(.symbolEffect(.replace))
          .frame(minWidth: 24, minHeight: 32)
        if let count, count > 0 {
          Text(count.compact)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
        }
      }
      .foregroundStyle(isActive ? activeColor : .secondary)
      .font(.footnote)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .sensoryFeedback(.selection, trigger: isActive)
  }
}

extension Int {
  var compact: String {
    formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
  }
}

extension Date {
  var shortRelative: String {
    let seconds = Date.now.timeIntervalSince(self)
    switch seconds {
    case ..<60: return "\(max(Int(seconds), 0))s"
    case ..<3_600: return "\(Int(seconds / 60))m"
    case ..<86_400: return "\(Int(seconds / 3_600))h"
    case ..<(86_400 * 7): return "\(Int(seconds / 86_400))d"
    default: return formatted(.dateTime.month(.abbreviated).day())
    }
  }
}
