//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

let keyVariableCaptureName = "KEY"
let translationVariableCaptureName = "TRANSLATION"
let translationSectionVariableCaptureName = "SECTION"
let anyStringVariableCaptureName = "ANYSTRING"

struct RegExpProvider {
    static func matchingStrings(regex: String, text: String, names: [String] = [keyVariableCaptureName]) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }

        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSMakeRange(0, text.count))

        return results
            .map { result -> [String] in
                names
                    .map { (name: String) -> String? in
                        result.range(withName: name).location != NSNotFound
                            ? nsText.substring(with: result.range(withName: name))
                            : nil
                    }
                    .compactMap { $0 }
            }
    }

    static func langName(for filePath: String) -> String? {
        guard !filePath.contains(".playground") else { return nil }
        let langPattern = #"\/(?<"# + keyVariableCaptureName + #">\S+)[.]lproj\/"#
        let key = matchingStrings(regex: langPattern, text: filePath).first?.first
        return key
    }

    static func getObjCKeyPattern(settings: Settings) -> String {
        var pattern = #"("#

        for prefix in settings.customObjCPatternPrefixes {
            pattern += escaped(prefix) + #"|"#
        }
        pattern.removeLast()
        pattern += #")@"(?<"# + keyVariableCaptureName + #">\S*)"\)*"#

        return pattern
    }

    static func escaped(_ string: String) -> String {
        return NSRegularExpression.escapedPattern(for: string)
    }

    static func getSwiftKeyPatterns(settings: Settings) -> [String] {
        var suffixPattern = #""(?<"# + keyVariableCaptureName + #">\S*)"("#

        for suffix in settings.customSwiftPatternSuffixes {
            suffixPattern += escaped(suffix) + #"|"#
        }
        suffixPattern.removeLast()
        suffixPattern += #")\(\)"#

        var prefixPattern = #"("#

        for prefix in settings.customSwiftPatternPrefixes {
            prefixPattern += escaped(prefix) + #"|"#
        }
        prefixPattern.removeLast()
        prefixPattern += #")\("(?<"# + keyVariableCaptureName + #">\S*)"\)"#

        return [prefixPattern, suffixPattern]
    }

    static func getAllSwiftStringPattern(settings: Settings) -> String {
        var pattern = ""

        settings.swiftPatternPrefixExceptions.forEach { exception in
            pattern += #"(?<!("# + escaped(exception) + #"))"#
        }

        pattern += #"(?:"(?<"# + keyVariableCaptureName + #">"#

        for prefix in settings.keyNamePrefixExceptions {
            pattern += #"(?!"# + escaped(prefix) + #")"#
        }

        pattern += settings.keyNamePattern + #")")*(?:"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

        return pattern
    }

    static func getAllObjCStringPattern(settings: Settings) -> String {
        var pattern = ""

        settings.objCPatternPrefixExceptions.forEach { exception in
            pattern += #"(?<!("# + escaped(exception) + #"))"#
        }

        pattern += #"(?:@"(?<"# + keyVariableCaptureName + #">"#
        for prefix in settings.keyNamePrefixExceptions {
            pattern += #"(?!"# + escaped(prefix) + #")"#
        }
        pattern += settings.keyNamePattern + #")")*(?:@"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

        return pattern
    }
}
