import Foundation

/// 中文 → 拼音转写。基于系统 CFStringTransform（Mandarin-Latin + 去声调），
/// 零数据文件；多音字取系统默认读音。混合文本按 CJK / 非 CJK 分段，仅转写 CJK 段。
public enum PinyinText {
    /// "团队会议" → "tuanduihuiyi"（小写、无声调、无分隔；非汉字原样保留，空白剔除）。
    public static func plain(_ text: String) -> String {
        segments(of: text)
            .map(\.pinyin)
            .joined()
            .lowercased()
            .filter { !$0.isWhitespace }
    }

    /// "团队会议" → "tdhy"（每个汉字音节取首字母；非汉字不参与）。
    public static func initials(_ text: String) -> String {
        var initials = ""
        for segment in segments(of: text) {
            guard segment.isCJK, let syllables = segment.syllableList else { continue }
            for syllable in syllables {
                if let first = syllable.first {
                    initials.append(first)
                }
            }
        }
        return initials.lowercased()
    }

    // MARK: - 分段

    private struct Segment {
        let source: String
        let isCJK: Bool
        /// CJK 段的转写结果（音节数组）；转写失败为 nil。
        let syllableList: [String]?

        var pinyin: String {
            guard isCJK, let syllableList else { return source }
            return syllableList.joined()
        }
    }

    private static func segments(of text: String) -> [Segment] {
        guard !text.isEmpty else { return [] }
        var result: [Segment] = []
        var buffer = ""
        var bufferIsCJK: Bool?

        func flush() {
            guard !buffer.isEmpty, let isCJK = bufferIsCJK else { return }
            result.append(Segment(
                source: buffer,
                isCJK: isCJK,
                syllableList: isCJK ? transcribe(buffer) : nil
            ))
            buffer = ""
            bufferIsCJK = nil
        }

        for scalar in text.unicodeScalars {
            let isCJK = (0x3400...0x9FFF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
            if let current = bufferIsCJK, current != isCJK {
                flush()
            }
            bufferIsCJK = isCJK
            buffer.unicodeScalars.append(scalar)
        }
        flush()
        return result
    }

    /// CJK 段转写：音节间以空白分隔，去声调。
    private static func transcribe(_ text: String) -> [String]? {
        let mutable = NSMutableAttributedString(string: text)
        let cfString = mutable.mutableString
        guard CFStringTransform(cfString, nil, kCFStringTransformMandarinLatin, false),
              CFStringTransform(cfString, nil, kCFStringTransformStripCombiningMarks, false) else {
            return nil
        }

        let parts = mutable.string
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts
    }
}
