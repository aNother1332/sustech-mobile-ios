import Foundation

/// Small HTML helpers for CAS fields and plain-text previews. Never executes HTML.
public enum HTMLText {
    public static func decoded(_ value: String) -> String {
        var text = value
        let matches = captures("&#(x[0-9a-fA-F]+|[0-9]+);", in: text)
        for match in matches {
            let raw = match[1]
            let number = raw.hasPrefix("x") ? UInt32(raw.dropFirst(), radix: 16) : UInt32(raw)
            if let number, let scalar = UnicodeScalar(number) {
                text = text.replacingOccurrences(of: match[0], with: String(scalar))
            }
        }
        for (entity, character) in [("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                                     ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    public static func plain(_ html: String) -> String {
        let noScript = html.replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: "", options: .regularExpression)
        let lines = noScript.replacingOccurrences(of: "(?i)<(?:br\\s*/?|/p|/div|/li)>", with: "\n", options: .regularExpression)
        let stripped = lines.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return decoded(stripped).replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func attributes(_ tag: String) -> [String: String] {
        var result: [String: String] = [:]
        for row in captures("([a-zA-Z_:][a-zA-Z0-9_:.-]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", in: tag) {
            result[row[1].lowercased()] = decoded(row.dropFirst(2).first(where: { !$0.isEmpty }) ?? "")
        }
        return result
    }

    public static func captures(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }
}
