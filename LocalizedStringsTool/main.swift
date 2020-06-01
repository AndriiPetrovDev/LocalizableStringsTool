//
//  main.swift
//  LocalizedStringsTool
//
//  Created by AndrewPetrov on 9/19/19.
//  Copyright © 2019 AndrewPetrov. All rights reserved.
//

import Cocoa
import Foundation

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
    let keyNamePattern: String
    let excludedKeys: [String]
    let excludedTranslationKeys: [String]
    let swiftPatternPrefixExceptions: [String]
    let objCPatternPrefixExceptions: [String]
    let folderExcludedNames: [String]

}

typealias TranslationPair = (key: String, translation: String)
struct Section {
    let name: String
    var translations: [TranslationPair]
}

struct TranslationKeysDiff {
    let firstLangName: String
    let secondLangName: String
    let firstAddedKeys: [String]
    let firstDeletedKeys: [String]
}

struct AnalysisResult {
    let unusedTranslations: [String: [Section]]
    let untranslatedKeys: [String: Set<String>]
    let translationDuplication: [String: [String: [String]]]?
    let allUntranslatedStrings: [String]?
    let differentKeysInTranslations: [TranslationKeysDiff]?
}

// MARK: - CALCULATE PROGRESS

let startTime = Date()
var commonFilesCount = 0
var currentFilesCountHandled = 0

// MARK: - GET FILE PATHS

var swiftFilePathSet = Set<String>()
var hFilePathSet = Set<String>()
var mFilePathSet = Set<String>()
var localizableFilePathArray = [String]()
var localizableDictFilePathArray = [String]()

let settingsFilePath = getSettingsFilePath()
var settingsFileFolder: String = ""
let settings: Settings = readPlist(settingsFilePath: settingsFilePath, settingsFileFolder: &settingsFileFolder)
print()

getAllFilesPaths(settings: settings,
                 swiftFilePathSet: &swiftFilePathSet,
                 hFilePathSet: &hFilePathSet,
                 mFilePathSet: &mFilePathSet,
                 localizableFilePathArray: &localizableFilePathArray,
                 localizableDictFilePathArray: &localizableDictFilePathArray
)

// MARK: - COLLECT KEYS

var swiftKeys = Set<String>()
var objCKeys = Set<String>()
var allStrings = Set<String>()
var allProbablyKeys = Set<String>()

//                      language
var localizationsDict = [String: [Section]]()
var availableKeys = [String: Set<String>]()

let concurrentQueue = DispatchQueue(label: "concurrentQueue", attributes: .concurrent)
let syncQueue = DispatchQueue(label: "Atomic serial queue")
let taskGroup = DispatchGroup()

if settings.shouldAnalyzeSwift {
    taskGroup.enter()
    concurrentQueue.async {
        let swiftKeyPatterns = getSwiftKeyPatterns(settings: settings)
        let allSwiftStringPattern = getAllSwiftStringPattern(settings: settings)
        processSwiftFiles(settings: settings,
                          swiftKeyPatterns: swiftKeyPatterns,
                          allSwiftStringPattern: allSwiftStringPattern,
                          swiftFilePathSet: swiftFilePathSet,
                          swiftKeys: &swiftKeys,
                          allStrings: &allStrings,
                          allProbablyKeys: &allProbablyKeys,
                          dispatchGroup: taskGroup)

    }
}
if settings.shouldAnalyzeObjC {
    taskGroup.enter()
    concurrentQueue.async {
        let objCFilePathSet = mFilePathSet.union(hFilePathSet)
        let objCKeyPattern = getObjCKeyPattern(settings: settings)
        let allObjCStringPattern = getAllObjCStringPattern(settings: settings)

        processObjCFiles(settings: settings,
                         objCKeyPattern: objCKeyPattern,
                         allObjCStringPattern: allObjCStringPattern,
                         objCFilePathSet: objCFilePathSet,
                         objCKeys: &objCKeys,
                         allStrings: &allStrings,
                         allProbablyKeys: &allProbablyKeys,
                         dispatchGroup: taskGroup)
    }
}

taskGroup.enter()
concurrentQueue.async {
    processLocalizableFiles(settings: settings,
                            localizableFilePathDict: localizableFilePathArray,
                            localizationsDict: &localizationsDict,
                            availableKeys: &availableKeys,
                            dispatchGroup: taskGroup)
}

taskGroup.enter()
concurrentQueue.async {
    processLocalizableDictFiles(settings: settings,
                                localizableDictFilePathDict: localizableDictFilePathArray,
                                availableKeys: &availableKeys,
                                dispatchGroup: taskGroup)
}

taskGroup.wait()

// MARK: - GET RESULTS

let result = getAnalysisResult(
    settings: settings,
    swiftKeys: swiftKeys,
    objCKeys: objCKeys,
    availableKeys: availableKeys,
    localizationsDict: localizationsDict
)
printShort(result: result)

// MARK: - SAVE FILES

saveToFile(result: result, settingsFileFolder: settingsFileFolder)

let endTime = Date()
let consumedTime = endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
print("consumed time: ", Int(consumedTime), "sec")

// MARK: - FUNCTIONS

func getSettingsFilePath() -> String? {
    print(#"Enter "LocalizedStringsTool.plist" absolute path:"#)
    let path = readLine()
    if let path = path, !path.isEmpty {
        return path
    } else {
        return nil
    }
}

func readPlist(settingsFilePath: String?, settingsFileFolder: inout String) -> Settings {
    let currentExecutablePath = CommandLine.arguments[0] as NSString
    let currentSettingsFilePath = currentExecutablePath.deletingLastPathComponent + "/LocalizedStringsTool.plist"
    let path = settingsFilePath ?? currentSettingsFilePath

    settingsFileFolder = ((path as NSString).deletingLastPathComponent as String)

    do {
        let fileURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileURL)

        return try PropertyListDecoder().decode(Settings.self, from: data)
    } catch {
        print(error.localizedDescription)
        print("Default settings will be used")

        return Settings(
            projectRootFolderPath: settingsFileFolder,
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
            keyNamePattern: #"[.]+"#,
            excludedKeys: [],
            excludedTranslationKeys: [],
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
    print(resultString)
}

func getAnalysisResult(settings: Settings,
                       swiftKeys: Set<String>,
                       objCKeys: Set<String>,
                       availableKeys: [String: Set<String>],
                       localizationsDict: [String: [Section]]) -> AnalysisResult {
    let combinedUsedLocalizedKeys = swiftKeys.union(objCKeys)
    var untranslatedKeys = [String: Set<String>]()

    availableKeys.keys.forEach { (key: String) in
        var usedKeys = combinedUsedLocalizedKeys
        usedKeys.subtract(availableKeys[key]!)
        usedKeys.subtract(Set(settings.excludedKeys))
        untranslatedKeys[key] = usedKeys
    }

    var unusedLocalizationsDict = [String: [Section]]()

    localizationsDict.keys.forEach { key in
        localizationsDict[key]?.forEach { (section: Section) in
            var unusedSection = Section(name: section.name, translations: [TranslationPair]())
            section.translations.forEach { pair in
                if !combinedUsedLocalizedKeys.contains(pair.key) && !settings.excludedTranslationKeys.contains(pair.key) {
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

    return AnalysisResult(
        unusedTranslations: unusedLocalizationsDict,
        untranslatedKeys: untranslatedKeys,
        translationDuplication: nil,
        allUntranslatedStrings: nil,
        differentKeysInTranslations: nil
    )
}

func printShort(result: AnalysisResult) {
    print("\nUntranslatedKeys:")
    result.untranslatedKeys.keys.sorted().forEach { key in
        print(key, result.untranslatedKeys[key]!.count)
    }
    print("\n\nUnusedTranslations")

    result.unusedTranslations.keys.sorted().forEach { key in
        let count = result.unusedTranslations[key]!.reduce(0) { (result: Int, section: Section) in result + section.translations.count }
        print(key, count)
    }
    print("\n")
}

func saveToFile(result: AnalysisResult, settingsFileFolder: String) {
    let outputFilePathUrl = URL(fileURLWithPath: settingsFileFolder + "/LocalizedStringsToolResults.txt")
    var resultTestString = "        LocalizedStringsToolResults\n"

    resultTestString += "\n\n   UntranslatedKeys:\n\n"
    result.untranslatedKeys.keys.sorted().forEach { langKey in
        let count = result.untranslatedKeys[langKey]!.count
        resultTestString += "\n" + langKey + ": \(count) \n"
        let keyArray: [String] = Array(result.untranslatedKeys[langKey]!)
        keyArray.sorted().forEach { key in
            resultTestString += "   " + key + "\n"
        }
    }

    resultTestString += "\n\n   UnusedTranslations:"

    result.unusedTranslations.keys.sorted().forEach { langKey in
        let count = result.unusedTranslations[langKey]!.reduce(0) { (result: Int, section: Section) in result + section.translations.count }
        resultTestString += "\n\n==================================\n"
        resultTestString += langKey + ": \(count)"
        resultTestString += "\n==================================\n\n"
        let sectionArray: [Section] = result.unusedTranslations[langKey]!
        sectionArray.forEach { section in
            resultTestString += "\n   " + section.name + "\n"
            section.translations.forEach { key, translation in
                resultTestString += "       " + key + "\n"
            }
        }
    }

    do {
        try resultTestString.write(to: outputFilePathUrl, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print(error)
    }
}

// MARK: - FILES PROCESSING

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

func processSwiftFiles(settings: Settings,
                       swiftKeyPatterns: [String],
                       allSwiftStringPattern: String,
                       swiftFilePathSet: Set<String>,
                       swiftKeys: inout Set<String>,
                       allStrings: inout Set<String>,
                       allProbablyKeys: inout Set<String>,
                       dispatchGroup: DispatchGroup) {
    let concurrentQueue = DispatchQueue(label: "processSwiftFiles", attributes: .concurrent)
    let taskGroup = DispatchGroup()

    var _swiftKeys = Set<String>()
    var _allStrings = Set<String>()
    var _allProbablyKeys = Set<String>()

    swiftFilePathSet.forEach { swiftFilePath in
        taskGroup.enter()
        concurrentQueue.async {
            autoreleasepool {
                if let fileText = try? String(
                    contentsOf: URL(fileURLWithPath: settings.projectRootFolderPath + "/" + swiftFilePath),
                    encoding: .utf8
                ) {
                    swiftKeyPatterns.forEach { pattern in
                        matchingStrings(regex: pattern, text: fileText)
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _swiftKeys.insert(key) } }
                    }
                    if settings.allUntranslatedStrings {
                        matchingStrings(regex: allSwiftStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _allStrings.insert(key) } }
                    }
                    matchingStrings(regex: allSwiftStringPattern, text: fileText)
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { key in syncQueue.sync { _allProbablyKeys.insert(key) } }
                }
            }
            increaseProgress()
            taskGroup.leave()
        }

    }
    taskGroup.wait()

    swiftKeys.formUnion(_swiftKeys)
    allStrings.formUnion(_allStrings)
    allProbablyKeys.formUnion(_allProbablyKeys)

    dispatchGroup.leave()
}

func processObjCFiles(settings: Settings,
                      objCKeyPattern: String,
                      allObjCStringPattern: String,
                      objCFilePathSet: Set<String>,
                      objCKeys: inout Set<String>,
                      allStrings: inout Set<String>,
                      allProbablyKeys: inout Set<String>,
                      dispatchGroup: DispatchGroup) {
    let concurrentQueue = DispatchQueue(label: "processObjCFiles", attributes: .concurrent)
    let taskGroup = DispatchGroup()

    var _objCKeys = Set<String>()
    var _allStrings = Set<String>()
    var _allProbablyKeys = Set<String>()

    objCFilePathSet.forEach { filePath in
        taskGroup.enter()
        concurrentQueue.async {
            autoreleasepool {
                if let fileText = try? String(contentsOf: URL(fileURLWithPath: settings.projectRootFolderPath + "/" + filePath), encoding: .utf8) {
                    matchingStrings(regex: objCKeyPattern, text: fileText)
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { key in syncQueue.sync { _objCKeys.insert(key) } }
                    if settings.allUntranslatedStrings {
                        matchingStrings(regex: allObjCStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _allStrings.insert(key) } }
                    }
                    matchingStrings(regex: allObjCStringPattern, text: fileText)
                        .map { $0.first }
                        .compactMap { $0 }
                        .forEach { key in syncQueue.sync { _allProbablyKeys.insert(key) } }
                }
            }
            increaseProgress()
            taskGroup.leave()
        }
    }

    taskGroup.wait()

    objCKeys.formUnion(_objCKeys)
    allStrings.formUnion(_allStrings)
    allProbablyKeys.formUnion(_allProbablyKeys)

    dispatchGroup.leave()
}

func processLocalizableFiles(settings: Settings,
                             localizableFilePathDict: [String],
                             localizationsDict: inout [String: [Section]],
                             availableKeys: inout [String: Set<String>],
                             dispatchGroup: DispatchGroup) {

    let localizedSectionPattern = #"(?<"# + translationSectionVariableCaptureName + #">(\/\*([^\*\/])+\*\/)|(\/\/.+\n+)+)*\n*(("(?<"# + keyVariableCaptureName + #">\S*)" = "(?<"# + translationVariableCaptureName + #">(.*)\s?)")*;)+"#

    let concurrentQueue = DispatchQueue(label: "processSwiftFiles", attributes: .concurrent)
    let taskGroup = DispatchGroup()

    var _localizationsDict = [String: [Section]]()
    var _availableKeys = [String: Set<String>]()

    localizableFilePathDict.forEach { dirPath in
        taskGroup.enter()
        concurrentQueue.async {
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
                        syncQueue.sync { _localizationsDict[name] = sections }
                        syncQueue.sync { _availableKeys[name] = oneLangAvailableKeys }
                    }
                }
            }
            increaseProgress()
            taskGroup.leave()
        }
    }
    taskGroup.wait()

    _localizationsDict.keys.forEach { key in
        var baseSections: [Section] = localizationsDict[key] ?? [Section]()
        let additionalSections: [Section] = _localizationsDict[key] ?? [Section]()
        baseSections.append(contentsOf: additionalSections)
        localizationsDict[key] = baseSections
    }

    _availableKeys.keys.forEach { key in
        var baseKeys: Set<String> = availableKeys[key] ?? Set<String>()
        let additionalKeys: Set<String> = _availableKeys[key] ?? Set<String>()
        baseKeys.formUnion(additionalKeys)
        availableKeys[key] = baseKeys
    }

    dispatchGroup.leave()
}

func processLocalizableDictFiles(settings: Settings,
                                 localizableDictFilePathDict: [String],
                                 availableKeys: inout [String: Set<String>],
                                 dispatchGroup: DispatchGroup) {

    let taskGroup = DispatchGroup()

    localizableDictFilePathDict.forEach { dirPath in
        taskGroup.enter()
        let path = (settings.projectRootFolderPath + "/" + dirPath)
        let fileURL = URL(fileURLWithPath: path)
        autoreleasepool {
            if let dict = NSDictionary(contentsOf: fileURL) as? Dictionary<String, AnyObject> {
                let name = langName(for: dirPath)
                syncQueue.sync {
                    availableKeys[name] = Set(dict.keys).union(availableKeys[name] ?? Set<String>())
                }
            }
        }
        increaseProgress()
        taskGroup.leave()
    }
    taskGroup.wait()

    dispatchGroup.leave()
}

// MARK: - REGEXP

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

func langName(for filePath: String) -> String {
    let langPattern = #"\/(?<"# + keyVariableCaptureName + #">\S+)[.]lproj\/"#
    return matchingStrings(regex: langPattern, text: filePath).first?.first ?? ""
}

func getObjCKeyPattern(settings: Settings) -> String {
    var pattern = #"("#

    for prefix in settings.customObjCPatternPrefixes {
        pattern += prefix + #"|"#
    }
    pattern.removeLast()
    pattern += #")@"(?<"# + keyVariableCaptureName + #">\S*)"\)*"#

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

    pattern += settings.keyNamePattern + #")")*(?:"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

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
    pattern += settings.keyNamePattern + #")")*(?:@"(?<"# + anyStringVariableCaptureName + #">\S*)")*"#

    return pattern
}
