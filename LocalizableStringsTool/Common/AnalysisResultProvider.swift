//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

struct AnalysisResultProvider {
    static func getAnalysisResult(settings: Settings,
                                  swiftKeys: Set<String>,
                                  objCKeys: Set<String>,
                                  availableKeys: [String: Set<String>],
                                  syncQueue: DispatchQueue,
                                  localizationsDict: [String: [Section]]) -> AnalysisResult {
        let combinedUsedLocalizedKeys = swiftKeys.union(objCKeys)
        var untranslatedKeys = [String: Set<String>]()

        availableKeys.keys.forEach { (key: String) in
            var usedKeys = combinedUsedLocalizedKeys
            usedKeys.subtract(availableKeys[key]!)
            usedKeys.subtract(Set(settings.excludedUntranslatedKeys))
            untranslatedKeys[key] = usedKeys
        }

        var unusedLocalizationsDict = [String: [Section]]()
        var translationDuplication = [String: [String: Set<String>]]()

        let concurrentQueue = DispatchQueue(label: "TranslationDuplication", attributes: .concurrent)
        let taskGroup = DispatchGroup()

        localizationsDict.keys.forEach { langKey in
            localizationsDict[langKey]?.forEach { (section: Section) in
                var unusedSection = Section(name: section.name, translations: [Translation]())
                section.translations.forEach { pair in
                    if !combinedUsedLocalizedKeys.contains(pair.key) && !settings.excludedUnusedKeys.contains(pair.key) {
                        unusedSection.translations.append(pair)
                    }
                }

                if unusedSection.translations.count > 0 {
                    if unusedLocalizationsDict[langKey] != nil {
                        unusedLocalizationsDict[langKey]?.append(unusedSection)
                    } else {
                        unusedLocalizationsDict[langKey] = [unusedSection]
                    }
                }
            }
        }

        if settings.translationDuplication {
            localizationsDict.keys.forEach { langKey in

                localizationsDict[langKey]?.forEach { (section: Section) in

                    section.translations.map { $0.value }
                        .forEach { targetTranslation in
                            taskGroup.enter()
                            concurrentQueue.async {
                                localizationsDict[langKey]?.forEach { (section: Section) in
                                    section.translations.forEach { translation in
                                        if translation.value == targetTranslation {
                                            syncQueue.sync {
                                                if translationDuplication.keys.contains(langKey) {
                                                    if translationDuplication[langKey]!.keys.contains(targetTranslation) {
                                                        if translationDuplication[langKey]![targetTranslation] != nil {
                                                            translationDuplication[langKey]![targetTranslation]!.insert(translation.key)
                                                        } else {}
                                                    } else {
                                                        var set = Set<String>()
                                                        set.insert(translation.key)
                                                        translationDuplication[langKey]![targetTranslation] = set
                                                    }
                                                } else {
                                                    var set = Set<String>()
                                                    set.insert(translation.key)
                                                    let dict: [String: Set<String>] = [targetTranslation: set]
                                                    translationDuplication[langKey] = dict
                                                }
                                            }
                                        }
                                    }
                                }
                                taskGroup.leave()
                            }
                        }
                }
            }
        }
        taskGroup.wait()
        var realTranslationDuplication = [String: [String: [String]]]()

        if settings.translationDuplication {
            translationDuplication.keys.forEach { langKey in
                translationDuplication[langKey]!.keys.forEach { translation in
                    if translationDuplication[langKey]![translation]!.count > 1 {
                        if realTranslationDuplication[langKey] != nil {
                            realTranslationDuplication[langKey]![translation] = Array(translationDuplication[langKey]![translation]!)
                        } else {
                            realTranslationDuplication[langKey] = [translation: Array(translationDuplication[langKey]![translation]!)]
                        }
                    }
                }
            }
        }

        var translationKeysDiffs = [TranslationKeysDiff]()

        if settings.differentKeysInTranslations {
            localizationsDict.keys.forEach { firstLangKey in
                localizationsDict.keys.forEach { secondLangKey in
                    let isPairAlreadyPresent = translationKeysDiffs.filter { $0.firstLangName == secondLangKey && $0.secondLangName == firstLangKey }.count > 0
                    if firstLangKey != secondLangKey, !isPairAlreadyPresent {
                        let firstKeys = localizationsDict[firstLangKey]!
                            .reduce(into: Set<String>()) { (result: inout Set<String>, section: Section) in
                                result.formUnion(Set(section.translations.map { $0.key }))
                            }

                        let secondKeys = localizationsDict[secondLangKey]!
                            .reduce(into: Set<String>()) { (result: inout Set<String>, section: Section) in
                                result.formUnion(Set(section.translations.map { $0.key }))
                            }

                        let firstAddedKeys = firstKeys.subtracting(secondKeys)
                        let firstDeletedKeys = secondKeys.subtracting(firstKeys)

                        let diff = TranslationKeysDiff(
                            firstLangName: firstLangKey,
                            secondLangName: secondLangKey,
                            firstAddedKeys: Array(firstAddedKeys).sorted(),
                            firstDeletedKeys: Array(firstDeletedKeys).sorted()
                        )
                        if diff.firstAddedKeys.count > 0 || diff.firstDeletedKeys.count > 0 {
                            translationKeysDiffs.append(diff)
                        }
                    }
                }
            }
        }

        return AnalysisResult(
            unusedTranslations: unusedLocalizationsDict,
            untranslatedKeys: untranslatedKeys,
            translationDuplication: realTranslationDuplication,
            allUntranslatedStrings: nil,
            differentKeysInTranslations: translationKeysDiffs
        )
    }

    static func printShort(result: AnalysisResult) {
        print("\nUntranslated Keys:")
        result.untranslatedKeys.keys.sorted().forEach { key in
            print(key, result.untranslatedKeys[key]!.count)
        }
        print("\n\nUnused Translations:")

        result.unusedTranslations.keys.sorted().forEach { key in
            let count = result.unusedTranslations[key]!.reduce(0) { (result: Int, section: Section) in result + section.translations.count }
            print(key, count)
        }

        if result.translationDuplication.count > 0 {
            print("\n\nDuplicated Translations:")
            result.translationDuplication.keys.sorted().forEach { key in
                print(key, result.translationDuplication[key]!.count)
            }
        }

        if result.differentKeysInTranslations.count > 0 {
            print("\nYou have different key sets for different languages")
        }
    }

    static func saveToFile(result: AnalysisResult, allStrings: [String], settingsFileFolder: String) {
        let outputFilePathUrl = URL(fileURLWithPath: settingsFileFolder + "/LocalizableStringsToolResults.txt")
        var resultTestString = "        LocalizableStringsToolResults\n"

        resultTestString += "\n\n   Untranslated Keys:\n\n"
        result.untranslatedKeys.keys.sorted().forEach { langKey in
            let count = result.untranslatedKeys[langKey]!.count
            resultTestString += "\n" + langKey + ": \(count) \n"
            let keyArray: [String] = Array(result.untranslatedKeys[langKey]!)
            keyArray.sorted().forEach { key in
                resultTestString += "   " + key + "\n"
            }
        }

        resultTestString += "\n\n   Unused Translations:"

        result.unusedTranslations.keys.sorted().forEach { langKey in
            let count = result.unusedTranslations[langKey]!.reduce(0) { (result: Int, section: Section) in result + section.translations.count }
            resultTestString += "\n\n==================================\n"
            resultTestString += langKey + ": \(count)"
            resultTestString += "\n==================================\n\n"
            let sectionArray: [Section] = result.unusedTranslations[langKey]!
            sectionArray.forEach { section in
                resultTestString += "\n   " + section.name + "\n"
                section.translations.forEach { translation in
                    resultTestString += "       " + translation.key + "\n"
                }
            }
        }

        if result.translationDuplication.count > 0 {
            resultTestString += "\n\n   Translation Duplication:"

            result.translationDuplication.keys.sorted().forEach { langKey in
                let count = result.translationDuplication[langKey]!.count
                resultTestString += "\n\n==================================\n"
                resultTestString += langKey + ": \(count)"
                resultTestString += "\n==================================\n\n"

                result.translationDuplication[langKey]!.forEach { translation, keys in
                    resultTestString += "\n   " + translation + "\n"
                    keys.forEach { key in
                        resultTestString += "       " + key + "\n"
                    }
                }
            }
        }

        if result.differentKeysInTranslations.count > 0 {
            resultTestString += "\n\n   Different Keys In Translations:"
            result.differentKeysInTranslations.forEach { diff in
                resultTestString += "\n\n==================================\n"
                resultTestString += diff.firstLangName + " compared to: " + diff.secondLangName + "\n"

                if diff.firstAddedKeys.count > 0 {
                    resultTestString += "\n   " + diff.firstLangName + " has extra keys: " + "\(diff.firstAddedKeys.count)" + "\n\n"
                    diff.firstAddedKeys.forEach { key in
                        resultTestString += "       " + key + "\n"
                    }
                }

                if diff.firstDeletedKeys.count > 0 {
                    resultTestString += "\n   " + diff.firstLangName + " has no keys: " + "\(diff.firstDeletedKeys.count)" + "\n\n"
                    diff.firstDeletedKeys.forEach { key in
                        resultTestString += "       " + key + "\n"
                    }
                }
            }
        }

        if allStrings.count > 0 {
            resultTestString += "\n\n   All Possible Untranslated \"KEYS\":"

            allStrings.forEach { string in
                resultTestString += "       " + string + "\n"
            }
        }

        do {
            try resultTestString.write(to: outputFilePathUrl, atomically: true, encoding: String.Encoding.utf8)
            print("Please check \(outputFilePathUrl.path) for details")
        } catch {
            print(error)
        }
    }
}
