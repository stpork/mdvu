import Foundation

enum HTML {
    static func escape(_ value: String, attribute: Bool = false) -> String {
        let needsEscape = attribute
            ? value.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" || $0 == "'" })
            : value.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" })
        guard needsEscape else { return value }
        var result = ""
        result.reserveCapacity(value.utf8.count + 64)
        var cursor = value.startIndex
        var search = cursor
        while search < value.endIndex {
            let ch = value[search]
            if ch == "&" || ch == "<" || ch == ">" || ch == "\"" || (attribute && ch == "'") {
                result.append(contentsOf: value[cursor..<search])
                switch ch {
                case "&": result.append("&amp;")
                case "<": result.append("&lt;")
                case ">": result.append("&gt;")
                case "\"": result.append("&quot;")
                case "'": result.append("&#39;")
                default: break
                }
                search = value.index(after: search)
                cursor = search
            } else {
                search = value.index(after: search)
            }
        }
        if cursor < value.endIndex {
            result.append(contentsOf: value[cursor...])
        }
        return result
    }

    static func escapeAttribute(_ value: String) -> String {
        escape(value, attribute: true)
    }

}
