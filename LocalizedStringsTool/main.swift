//
//  main.swift
//  LocalizedStringsTool
//
//  Created by AndrewPetrov on 9/19/19.
//  Copyright © 2019 AndrewPetrov. All rights reserved.
//

import Cocoa
import Foundation

/*
 + получить текущую папку или прочитать путь
 + получить список всех .swift, .h, .m файлов
 + прочитать из каждого строки
 + составить сет из этих ключей “usedKeys”
 + получить список файлов .strings
 + составить массив из ключей “availableKeys” для каждого языка
 + “usedKeys” -   “availableKeys” = ключи без перевода (точно)
 + ключи без перевода (возможно)
 + “availableKeys” - “usedKeys” = неиспользуемые ключи
 + дублирование переводов
 + поддержка обж с
 + добавить все исключения из моно
 + оптимизация потребления памяти
 + указание пути
 + получить инфу со stringdict
 + сортировка как в файле с переводами
 + сепараторы секций переводов как в оригинале
 + добавить дефольные настройки
 + загрузка настроек из файла
 + разные ключи в разных файлах перевода
 - добавить все исключения из обычных проектов
 - рефакторинг
 - кастомные правила для ключей
 + кастомные исключения
 - csv export
 + отображать прогресс

 */

let keyVariableCaptureName = "KEY"
let translationVariableCaptureName = "TRANSLATION"
let translationSectionVariableCaptureName = "SECTION"
let anyStringVariableCaptureName = "ANYSTRING"

// MARK: - SETTINGS

struct Settings: Decodable {
    let projectRootFolderPath: String

    let unusedTranslations: Bool
    let translationDuplication: Bool
    let untranslatedKeys: Bool
    let allUntranslatedStrings: Bool
    let differentKeysInTranslations: Bool

    let shouldAnalyzeSwift: Bool
    let shouldAnalyzeObjC: Bool

    let customSwiftPatternPrefixes: [String]
    let customSwiftPatternSuffixes: [String]
    let customObjCPatternPrefixes: [String]

    let keyNamePrefixExceptions: [String]
    let swiftPatternPrefixExceptions: [String]
    let objCPatternPrefixExceptions: [String]
    let folderExcludedNames: [String]

}

typealias TranslationPair = (key: String, translation: String)
struct Section {
    let name: String
    var translations: [TranslationPair]
}

// MARK: - PROGRESS CALCULATION

let startTime = Date()
var commonFilesCount = 0
var currentFilesCountHandled = 0

//let executableName = CommandLine.arguments[0] as NSString
//print(executableName)

//let argCount = CommandLine.argc

// MARK: -GET FILE PATHS

var swiftFilePathSet = Set<String>()
var hFilePathSet = Set<String>()
var mFilePathSet = Set<String>()
var localizableFilePathArray = [String]()
var localizableDictFilePathArray = [String]()

var settings: Settings = readPlist()

getAllFilesPaths(settings: settings,
                 swiftFilePathSet: &swiftFilePathSet,
                 hFilePathSet: &hFilePathSet,
                 mFilePathSet: &mFilePathSet,
                 localizableFilePathArray: &localizableFilePathArray,
                 localizableDictFilePathArray: &localizableDictFilePathArray
)

// MARK: - COLLECTING KEYS

var swiftKeys = Set<String>()
var objCKeys = Set<String>()
var allStrings = Set<String>()
var allProbablyKeys = Set<String>()

//                      language
var localizationsDict = [String: [Section]]()

if settings.shouldAnalyzeSwift {
    let swiftKeyPatterns = getSwiftKeyPatterns(settings: settings)
    let allSwiftStringPattern = getAllSwiftStringPattern(settings: settings)
    processSwiftFiles(settings: settings,
                      swiftKeyPatterns: swiftKeyPatterns,
                      allSwiftStringPattern: allSwiftStringPattern,
                      swiftFilePathSet: swiftFilePathSet,
                      swiftKeys: &swiftKeys,
                      allStrings: &allStrings,
                      allProbablyKeys: &allProbablyKeys)

}

if settings.shouldAnalyzeObjC {
    let objCFilePathSet = mFilePathSet.union(hFilePathSet)
    let objCKeyPattern = getObjCKeyPattern(settings: settings)
    let allObjCStringPattern = getAllObjCStringPattern(settings: settings)

    processObjCFiles(settings: settings,
                     objCKeyPattern: objCKeyPattern,
                     allObjCStringPattern: allObjCStringPattern,
                     objCFilePathSet: objCFilePathSet,
                     objCKeys: &objCKeys,
                     allStrings: &allStrings,
                     allProbablyKeys: &allProbablyKeys)
}

var availableKeys = [String: Set<String>]()

processLocalizableFiles(settings: settings,
                        localizableFilePathDict: localizableFilePathArray,
                        localizationsDict: &localizationsDict,
                        availableKeys: &availableKeys)

processLocalizableDictFiles(settings: settings,
                            localizableDictFilePathDict: localizableDictFilePathArray,
                            availableKeys: &availableKeys)

// MARK: - GET RESULTS

let combinedUsedLocalizedKeys = swiftKeys.union(objCKeys)
var untranslatedKeys = [String: Set<String>]()

availableKeys.keys.forEach { (key: String) in
    var usedKeys = combinedUsedLocalizedKeys
    usedKeys.subtract(availableKeys[key]!)
    untranslatedKeys[key] = usedKeys
}

var unusedLocalizationsDict = [String: [Section]]()

localizationsDict.keys.forEach { key in
    localizationsDict[key]?.forEach { (section: Section) in
        var unusedSection = Section(name: section.name, translations: [TranslationPair]())
        section.translations.forEach { pair in
            if !combinedUsedLocalizedKeys.contains(pair.key) {
                unusedSection.translations.append(pair)
            }
        }
        if unusedSection.translations.count > 0 {
            if unusedLocalizationsDict[key] != nil {
                unusedLocalizationsDict[key]?.append(unusedSection)
            } else {
                unusedLocalizationsDict[key] = [unusedSection]
            }
        }
    }
}

untranslatedKeys.keys.forEach { key in
    print(key, untranslatedKeys[key]!.count)
}

// SAVE FILES

let endTime = Date()
let consumedTime = endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
print("consumed time: ", Int(consumedTime), "sec")

//dump(unusedLocalizationsDict)

/*

// [lang: Set<key>]
let langKeysDict = localizationsDict.mapValues { Set($0.keys) }
let langTranslationsDict = localizationsDict.mapValues { Set($0.values) }

let langKeysSubtractUsedKeysDict = langKeysDict.mapValues { $0.subtracting(combinedUsedLocalizedKeys) }
// subtract all used strings because sometimes they used as just strings without localized construction
let extraTranslations = langKeysSubtractUsedKeysDict.mapValues { $0.subtracting(allSwiftStrings) }

if settings.translationDuplication {
    let duplicatedTranslations = localizationsDict.mapValues { (oneLangDict: [String: String]) -> [String: [String]] in
        //  translation: keys
        var translationKeysDict = [String: [String]]()

        oneLangDict.forEach { (arg: (key: String, value: String)) in
            let (key, value) = arg
            if translationKeysDict[value] != nil {
                translationKeysDict[value]!.append(key)
            } else {
                translationKeysDict[value] = [key]
            }
        }

        return translationKeysDict.filter { _, value in value.count > 1 }
    }

    print("duplicatedTranslations")
    dump(duplicatedTranslations)
}

print("\n\n")
print("extraTranslations")
//print(extraTranslations)
dump(extraTranslations)

// print("allSwiftStrings")
// dump(allSwiftStrings)

// print("allProbablyKeys")
// dump(allProbablyKeys)

print("keys without translation")
let keysWithoutTranslation = langKeysDict.mapValues { combinedUsedLocalizedKeys.subtracting($0) }

print(keysWithoutTranslation)

print("probably keys without translation")
let probablyKeysWithoutTranslation = langKeysDict.mapValues { allProbablyKeys.subtracting($0).subtracting(combinedUsedLocalizedKeys.subtracting($0)) }

print(probablyKeysWithoutTranslation)
*/

// FUNCTIONS

func readPlist() -> Settings {

    //    let path = FileManager.default.currentDirectoryPath + "/LocalizedStringsTool.plist"
    let path = "/Users/andrewmbp-office/Library/Developer/Xcode/DerivedData/LocalizedStringsTool-blwtdzgdconutmbtojnabaztzxrf/Build/Products/Debug/LocalizedStringsTool.plist"

    do {
        let fileURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileURL)
        return try PropertyListDecoder().decode(Settings.self, from: data)

    } catch {
        NSLog(error.localizedDescription)
        NSLog("Default settings will be used")

        return Settings(
            projectRootFolderPath: FileManager.default.currentDirectoryPath,
            unusedTranslations: true,
            translationDuplication: true,
            untranslatedKeys: true,
            allUntranslatedStrings: false,
            differentKeysInTranslations: false,
            shouldAnalyzeSwift: true,
            shouldAnalyzeObjC: true,
            customSwiftPatternPrefixes: [#"NSLocalizedString("#],
            customSwiftPatternSuffixes: [],
            customObjCPatternPrefixes: [#"NSLocalizedString("#],
            keyNamePrefixExceptions: [],
            swiftPatternPrefixExceptions: [],
            objCPatternPrefixExceptions: [],
            folderExcludedNames: ["Pods"]
        )

    }
}

func increaseProgress() {
    currentFilesCountHandled += 1

    let maxLength = 50
    var currentLength = (maxLength * currentFilesCountHandled) / commonFilesCount

    currentLength = max(0, currentLength)
    var progressString = ""
    for _ in 0 ..< currentLength {
        progressString += "■"
    }
    for _ in 0 ..< maxLength - currentLength {
        progressString += "□"
    }
    let resultString = String(format: "\u{1B}[1A\u{1B} %@ ", progressString)
    //    print(resultString)
}

func getAllFilesPaths(settings: Settings,
                      swiftFilePathSet: inout Set<String>,
                      hFilePathSet: inout  Set<String>,
                      mFilePathSet: inout Set<String>,
                      localizableFilePathArray: inout [String],
                      localizableDictFilePathArray: inout [String]) {
    let manager = FileManager.default
    let enumerator = manager.enumerator(atPath: settings.projectRootFolderPath)

    while let element = enumerator?.nextObject() as? String {
        var shouldHandlePath = true
        for pathElement in settings.folderExcludedNames {
            if element.contains(pathElement) {
                shouldHandlePath = false
            }
        }

        if shouldHandlePath {
            if element.hasSuffix(".swift") && settings.shouldAnalyzeSwift {
                swiftFilePathSet.insert(element)
            } else if element.hasSuffix(".h") && settings.shouldAnalyzeObjC {
                hFilePathSet.insert(element)
            } else if element.hasSuffix(".m") && settings.shouldAnalyzeObjC {
                mFilePathSet.insert(element)
            } else if element.hasSuffix("Localizable.strings") {
                localizableFilePathArray.append(element)
            } else if element.hasSuffix("Localizable.stringsdict") {
                localizableDictFilePathArray.append(element)
            }
        }
        commonFilesCount = swiftFilePathSet.count + hFilePathSet.count + mFilePathSet.count + localizableFilePathArray.count + localizableDictFilePathArray.count
    }
}

func matchingStrings(regex: String, text: String, names: [String] = [keyVariableCaptureName]) -> [[String]] {
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

func processSwiftFiles(settings: Settings,
                       swiftKeyPatterns: [String],
                       allSwiftStringPattern: String,
                       swiftFilePathSet: Set<String>,
                       swiftKeys: inout Set<String>,
                       allStrings: inout Set<String>,
                       allProbablyKeys: inout Set<String>) {
    swiftFilePathSet.forEach { swiftFilePath in
        autoreleasepool {
            if let fileText = try? String(
                contentsOf: URL(fileURLWithPath: settings.projectRootFolderPath + "/" + swiftFilePath),
                encoding: .utf8
            ) {
                swiftKeyPatterns.forEach { pattern in
                    matchingStrings(regex: pattern, text: fileText)
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { swiftKeys.insert($0) }
                }
                if settings.allUntranslatedStrings {
                    matchingStrings(regex: allSwiftStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { allStrings.insert($0) }
                }
                matchingStrings(regex: allSwiftStringPattern, text: fileText)
                    .map { $0.first }
                    .compactMap { $0 }
                    .forEach { allProbablyKeys.insert($0) }
            }
        }
        increaseProgress()
    }
}

func processObjCFiles(settings: Settings,
                      objCKeyPattern: String,
                      allObjCStringPattern: String,
                      objCFilePathSet: Set<String>,
                      objCKeys: inout Set<String>,
                      allStrings: inout Set<String>,
                      allProbablyKeys: inout Set<String>) {

    objCFilePathSet.forEach { filePath in
        autoreleasepool {
            if let fileText = try? String(contentsOf: URL(fileURLWithPath: settings.projectRootFolderPath + "/" + filePath), encoding: .utf8) {
                matchingStrings(regex: objCKeyPattern, text: fileText)
                    .map { $0.first }
                    .compactMap { $0 }
                    .forEach { objCKeys.insert($0) }
                if settings.allUntranslatedStrings {
                    matchingStrings(regex: allObjCStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { allStrings.insert($0) }
                }
                matchingStrings(regex: allObjCStringPattern, text: fileText)
                    .map { $0.first }
                    .compactMap { $0 }
                    .forEach { allProbablyKeys.insert($0) }
            }
        }
        increaseProgress()
    }
}

func processLocalizableFiles(settings: Settings,
                             localizableFilePathDict: [String],
                             localizationsDict: inout [String: [Section]],
                             availableKeys: inout [String: Set<String>]) {
    let localizedSectionPattern = #"(?<"# + translationSectionVariableCaptureName + #">(\/\*([^\*\/])+\*\/)|(\/\/.+\n+)+)*\n*(("(?<"# + keyVariableCaptureName + #">\S*)" = "(?<"# + translationVariableCaptureName + #">(.*)\s?)")*;)+"#

    localizableFilePathDict.forEach { dirPath in
        autoreleasepool {
            let path = (settings.projectRootFolderPath + "/" + dirPath)
            do {
                var oneLangAvailableKeys = Set<String>()
                // Koto utf8, Mono utf16
                let fileText8 = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
                let fileText16 = try? String(contentsOf: URL(fileURLWithPath: path), encoding: .utf16)
                let arr = [fileText8, fileText16].compactMap { $0 }

                if let fileText = arr.first {
                    let searchResults: [[String]] = matchingStrings(
                        regex: localizedSectionPattern,
                        text: fileText,
                        names: [translationSectionVariableCaptureName, keyVariableCaptureName, translationVariableCaptureName]
                    )
                    var sections = [Section]()

                    for result: [String] in searchResults {
                        // found new section
                        if result.count == 3 {
                            sections.append(Section(name: result[0], translations: [TranslationPair(key: result[1], translation: result[2])]))
                            oneLangAvailableKeys.insert(result[1])

                            // add to previous section
                        } else if result.count == 2 {
                            oneLangAvailableKeys.insert(result[0])
                            if sections.count > 0 {
                                sections[sections.count - 1].translations.append(TranslationPair(key: result[0], translation: result[1]))
                            } else {
                                sections.append(Section(name: "", translations: [TranslationPair(key: result[0], translation: result[1])]))
                            }
                        }
                    }
                    let name = langName(for: dirPath)
                    localizationsDict[name] = sections
                    availableKeys[name] = oneLangAvailableKeys
                }
            }
        }
        increaseProgress()
    }
}

func processLocalizableDictFiles(settings: Settings,
                                 localizableDictFilePathDict: [String],
                                 availableKeys: inout [String: Set<String>]) {

    localizableDictFilePathDict.forEach { dirPath in
        let path = (settings.projectRootFolderPath + "/" + dirPath)
        let fileURL = URL(fileURLWithPath: path)
        autoreleasepool {
            if let dict = NSDictionary(contentsOf: fileURL) as? Dictionary<String, AnyObject> {
                let name = langName(for: dirPath)
                availableKeys[name] = availableKeys[name]?.union(Set(dict.keys))
            }
        }
        increaseProgress()
    }
}

func langName(for filePath: String) -> String {
    let langPattern = #"\/(?<"# + keyVariableCaptureName + #">\S+)[.]lproj\/"#
    return matchingStrings(regex: langPattern, text: filePath).first?.first ?? ""
}

// REGEXP PATTERNS

func getObjCKeyPattern(settings: Settings) -> String {
    var pattern = #"("#

    for prefix in settings.customObjCPatternPrefixes {
        pattern += prefix + #"|"#
    }
    pattern.removeLast()
    pattern += #")\(@"(?<"# + keyVariableCaptureName + #">\S*)"\)"#

    return pattern
}

func getSwiftKeyPatterns(settings: Settings) -> [String] {
    var suffixPattern = #""(?<"# + keyVariableCaptureName + #">\S*)"("#

    for suffix in settings.customSwiftPatternSuffixes {
        suffixPattern += suffix + #"|"#
    }
    suffixPattern.removeLast()
    suffixPattern += #")\(\)"#

    var prefixPattern = #"("#

    for prefix in settings.customSwiftPatternPrefixes {
        prefixPattern += prefix + #"|"#
    }
    prefixPattern.removeLast()
    prefixPattern += #")\("(?<"# + keyVariableCaptureName + #">\S*)"\)"#

    return [prefixPattern, suffixPattern]
}

func getAllSwiftStringPattern(settings: Settings) -> String {
    var pattern = ""

    settings.swiftPatternPrefixExceptions.forEach { exception in
        pattern += #"(?<!("# + exception + #"))"#
    }

    pattern += #"(?:"(?<"# + keyVariableCaptureName + #">"#
    for prefix in settings.keyNamePrefixExceptions {
        pattern += #"(?!"# + prefix + #")"#
    }

    pattern += #"[_a-z0-9]*[_][a-z0-9]+)")*(?:"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

    return pattern
}

func getAllObjCStringPattern(settings: Settings) -> String {
    var pattern = ""

    settings.objCPatternPrefixExceptions.forEach { exception in
        pattern += #"(?<!("# + exception + #"))"#
    }

    pattern += #"(?:@"(?<"# + keyVariableCaptureName + #">"#
    for prefix in settings.keyNamePrefixExceptions {
        pattern += #"(?!"# + prefix + #")"#
    }
    pattern += #"[_a-z0-9]*[_][a-z0-9]+)")*(?:@"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

    return pattern
}