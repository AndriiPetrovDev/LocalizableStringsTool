//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

struct FileProcessor {
    static func processSwiftFiles(settings: Settings,
                                  swiftKeyPatterns: [String],
                                  allSwiftStringPattern: String,
                                  swiftFilePathSet: Set<String>,
                                  swiftKeys: inout Set<String>,
                                  allStrings: inout Set<String>,
                                  allProbablyKeys: inout Set<String>,
                                  syncQueue: DispatchQueue,
                                  parentTaskGroup: DispatchGroup,
                                  progressHelper: ProgressLogger) {
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
                            RegExpProvider.matchingStrings(regex: pattern, text: fileText)
                                .map { $0.first }
                                .compactMap { $0 }
                                .forEach { key in syncQueue.sync { _swiftKeys.insert(key) } }
                        }
                        if settings.allUntranslatedStrings {
                            RegExpProvider.matchingStrings(regex: allSwiftStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                                .map { $0.first }
                                .compactMap { $0 }
                                .forEach { key in syncQueue.sync { _allStrings.insert(key) } }
                        }
                        RegExpProvider.matchingStrings(regex: allSwiftStringPattern, text: fileText)
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _allProbablyKeys.insert(key) } }
                    }
                }
                progressHelper.increaseProgress()
                taskGroup.leave()
            }
        }
        taskGroup.wait()

        swiftKeys.formUnion(_swiftKeys)
        allStrings.formUnion(_allStrings)
        allProbablyKeys.formUnion(_allProbablyKeys)

        parentTaskGroup.leave()
    }

    static func processObjCFiles(settings: Settings,
                                 objCKeyPattern: String,
                                 allObjCStringPattern: String,
                                 objCFilePathSet: Set<String>,
                                 objCKeys: inout Set<String>,
                                 allStrings: inout Set<String>,
                                 allProbablyKeys: inout Set<String>,
                                 syncQueue: DispatchQueue,
                                 parentTaskGroup: DispatchGroup,
                                 progressHelper: ProgressLogger) {
        let concurrentQueue = DispatchQueue(label: "processObjCFiles", attributes: .concurrent)
        let taskGroup = DispatchGroup()

        var _objCKeys = Set<String>()
        var _allStrings = Set<String>()
        var _allProbablyKeys = Set<String>()

        objCFilePathSet.forEach { filePath in
            taskGroup.enter()
            concurrentQueue.async {
                autoreleasepool {
                    if let fileText = try? String(
                        contentsOf: URL(fileURLWithPath: settings.projectRootFolderPath + "/" + filePath),
                        encoding: .utf8
                    ) {
                        RegExpProvider.matchingStrings(regex: objCKeyPattern, text: fileText)
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _objCKeys.insert(key) } }
                        if settings.allUntranslatedStrings {
                            RegExpProvider.matchingStrings(regex: allObjCStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                                .map { $0.first }
                                .compactMap { $0 }
                                .forEach { key in syncQueue.sync { _allStrings.insert(key) } }
                        }
                        RegExpProvider.matchingStrings(regex: allObjCStringPattern, text: fileText)
                            .map { $0.first }
                            .compactMap { $0 }
                            .forEach { key in syncQueue.sync { _allProbablyKeys.insert(key) } }
                    }
                }
                progressHelper.increaseProgress()
                taskGroup.leave()
            }
        }

        taskGroup.wait()

        objCKeys.formUnion(_objCKeys)
        allStrings.formUnion(_allStrings)
        allProbablyKeys.formUnion(_allProbablyKeys)

        parentTaskGroup.leave()
    }

    static func processLocalizableFiles(settings: Settings,
                                        localizableFilePathDict: [String],
                                        localizationsDict: inout [String: [Section]],
                                        availableKeys: inout [String: Set<String>],
                                        syncQueue: DispatchQueue,
                                        parentTaskGroup: DispatchGroup,
                                        progressHelper: ProgressLogger) {
        let localizedSectionPattern = #"(?<"# + translationSectionVariableCaptureName + #">(\/\*([^\*\/])+\*\/)|(\/\/.+\n+)+)*\n*("(?<"# + keyVariableCaptureName + #">\S*)" = "(?<"# + translationVariableCaptureName + #">.+?\s*?.+?)";)+?"#

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
                            let searchResults: [[String]] = RegExpProvider.matchingStrings(
                                regex: localizedSectionPattern,
                                text: fileText,
                                names: [translationSectionVariableCaptureName, keyVariableCaptureName, translationVariableCaptureName]
                            )
                            var sections = [Section]()

                            for result: [String] in searchResults {
                                // found new section
                                if result.count == 3 {
                                    sections.append(Section(name: result[0], translations: [Translation(key: result[1], value: result[2])]))
                                    oneLangAvailableKeys.insert(result[1])

                                    // add to previous section
                                } else if result.count == 2 {
                                    oneLangAvailableKeys.insert(result[0])
                                    if sections.count > 0 {
                                        sections[sections.count - 1].translations.append(Translation(key: result[0], value: result[1]))
                                    } else {
                                        sections.append(Section(name: "", translations: [Translation(key: result[0], value: result[1])]))
                                    }
                                }
                            }
                            if let name = RegExpProvider.langName(for: dirPath) {
                                syncQueue.sync { _localizationsDict[name] = sections }
                                syncQueue.sync { _availableKeys[name] = oneLangAvailableKeys }
                            }
                        }
                    }
                }
                progressHelper.increaseProgress()
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

        parentTaskGroup.leave()
    }

    static func processLocalizableDictFiles(settings: Settings,
                                            localizableDictFilePathDict: [String],
                                            availableKeys: inout [String: Set<String>],
                                            syncQueue: DispatchQueue,
                                            parentTaskGroup: DispatchGroup,
                                            progressHelper: ProgressLogger) {
        localizableDictFilePathDict.forEach { dirPath in
            let path = (settings.projectRootFolderPath + "/" + dirPath)
            let fileURL = URL(fileURLWithPath: path)
            autoreleasepool {
                if let dict = NSDictionary(contentsOf: fileURL) as? [String: AnyObject] {
                    if let name = RegExpProvider.langName(for: dirPath) {
                        syncQueue.sync {
                            availableKeys[name] = Set(dict.keys).union(availableKeys[name] ?? Set<String>())
                        }
                    }
                }
            }
            progressHelper.increaseProgress()
        }

        parentTaskGroup.leave()
    }

    static func readPlist(settingsFilePath: String?, settingsFileFolder: inout String) -> Settings {
        let currentExecutablePath = CommandLine.arguments[0] as NSString
        let currentSettingsFilePath = currentExecutablePath.deletingLastPathComponent + "/LocalizableStringsTool.plist"
        let path = settingsFilePath ?? currentSettingsFilePath

        settingsFileFolder = ((path as NSString).deletingLastPathComponent as String)

        do {
            let fileURL = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: fileURL)

            var settings = try PropertyListDecoder().decode(Settings.self, from: data)
            if settings.projectRootFolderPath == "" || settings.projectRootFolderPath == " " {
                settings.projectRootFolderPath = getProjectRootFolderPath()
            }
            return settings
        } catch {
            print(error.localizedDescription)
            print("Default settings will be used")

            let projectRootFolderPath = getProjectRootFolderPath()
            settingsFileFolder = projectRootFolderPath

            return Settings(
                projectRootFolderPath: projectRootFolderPath,
                unusedTranslations: true,
                translationDuplication: true,
                untranslatedKeys: true,
                allUntranslatedStrings: false,
                differentKeysInTranslations: true,
                shouldAnalyzeSwift: true,
                shouldAnalyzeObjC: true,
                customSwiftPatternPrefixes: [#"NSLocalizedString("#],
                customSwiftPatternSuffixes: [],
                customObjCPatternPrefixes: [#"NSLocalizedString("#],
                keyNamePrefixExceptions: [],
                keyNamePattern: #"[.]+"#,
                excludedUntranslatedKeys: [],
                excludedUnusedKeys: [],
                swiftPatternPrefixExceptions: [],
                objCPatternPrefixExceptions: [],
                excludedFoldersNameComponents: ["Pods"]
            )
        }
    }

    private static func getProjectRootFolderPath() -> String {
        var projectRootFolderPath = ""

        while projectRootFolderPath == "" || projectRootFolderPath == " " {
            print(#"Enter project root folder absolute path:"#)
            projectRootFolderPath = readLine() ?? ""
            if projectRootFolderPath.prefix(2) == #"//"# {
                projectRootFolderPath = String(projectRootFolderPath.dropFirst())
            }
            if projectRootFolderPath.prefix(1) != #"/"# {
                projectRootFolderPath = #"/"# + projectRootFolderPath
            }
            if projectRootFolderPath.suffix(1) == #"/"# {
                projectRootFolderPath = String(projectRootFolderPath.dropLast())
            }
            print("")
        }
        return projectRootFolderPath
    }
}
