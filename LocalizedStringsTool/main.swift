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
 - добавить все исключения из обычных проектов
 + указание пути
 - рефакторинг
 - кастомные правила для ключей
 + кастомные исключения
 - добавить дефольные настройки
 - разные ключи в разных файлах перевода
 - загрузка настроек из файла
 - csv export
 - отображать прогресс

 */

// MARK: - OPTIONS

struct Settings: Decodable {
    let projectRootFolderPath: String

    let unusedTranslations: Bool = true
    let translationDuplication: Bool = true
    let untranslatedKeys: Bool = true
    let allUntranslatedStrings: Bool = false
    let differentKeysInTranslations: Bool = true
    let objCExceptions: [String]
    let swiftExceptions: [String]

}
var settings: Settings!

var projectPath = "/Users/andrewmbp-office/ftband-bank-ios"

private func readPlist() {
    //    let path = FileManager.default.currentDirectoryPath + "/LocalizedStringsTool.plist"
    let path = "/Users/andrewmbp-office/Library/Developer/Xcode/DerivedData/LocalizedStringsTool-blwtdzgdconutmbtojnabaztzxrf/Build/Products/Debug/LocalizedStringsTool.plist"

    do {
        let fileURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: fileURL)
        settings = try PropertyListDecoder().decode(Settings.self, from: data)//, format: &plistFormat)
        dump(settings)
    } catch {
        print(error)
    }

}

readPlist()

//let executableName = CommandLine.arguments[0] as NSString
//print(executableName)

//let argCount = CommandLine.argc

// let path = "/Users/andrewmbp-office/app-ios-client/Koto"

let settingsFilePath = "/Users/Shared/Previously Relocated Items/Security/develop/LocalizedStringsTool/LocalizedStringsTool/LocalizedStringsTool.plist"

var swiftFilePathSet = Set<String>()
var hFilePathSet = Set<String>()
var mFilePathSet = Set<String>()
var localizableFilePathDict = [String]()

let settingsFile = URL(fileURLWithPath: settingsFilePath)

let manager = FileManager.default
let enumerator = manager.enumerator(atPath: projectPath)
let content = try? manager.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath)

while let element = enumerator?.nextObject() as? String {
    //    , !element.contains("PresentationLayer")
    guard !element.contains("Pods"), !element.contains("MiSnapSDK") else {
        continue
    }
    if element.hasSuffix(".swift") {
        swiftFilePathSet.insert(element)
    } else if element.hasSuffix(".h") {
        hFilePathSet.insert(element)
    } else if element.hasSuffix(".m") {
        mFilePathSet.insert(element)
    } else if element.hasSuffix(".lproj") {
        localizableFilePathDict.append(element)
    }
}

var swiftKeys = Set<String>()
var mKeys = Set<String>()
var allSwiftStrings = Set<String>()
var allSwiftProbablyKeys = Set<String>()
var allObjCProbablyKeys = Set<String>()
var allProbablyKeys = Set<String>()

//                     [lang: [key: translation]
var localizationsDict = [String: [String: String]]()

let keyVariableCaptureName = "KEY"
let translationVariableCaptureName = "TRANSLATION"
let anyStringVariableCaptureName = "ANYSTRING"

let swiftKeyPattern = #""(?<KEY>\S*)".localized\(\)"#
let swiftOldKeyPattern = #"lang\("(?<KEY>\S*)"\)"#

let objCKeyPattern = #"(lang|title|subtitle|advice|buttonTitle|rescanTitle|rescanSubtitle)\(@"(?<KEY>\S*)"\)"#
let localizedPairPattern = #""(?<KEY>\S*)" = "(?<TRANSLATION>(.*)\s?)";"#

var allObjCStringPattern = ""

/*let objCExceptions = [
    #"setAnimation:"#,
    #".animation\("#,
    #"configureWithAnimation:"#,
    #"secondAnimation:"#,
    #"imageNamed:"#,
    #"userInfo\["#,
    #".appData\["#,
    #"addAnimationViewFromFirstAnimation:"#,
]*/

settings.objCExceptions.forEach { exception in
    allObjCStringPattern += #"(?<!("# + exception + #"))"#
}

allObjCStringPattern += #"(?:@"(?<KEY>(?!ic_)[_a-z0-9]*[_][a-z0-9]+)")*(?:@"(?<ANYSTRING>\S*)")*"#

var allSwiftStringPattern = ""
/*let swiftExceptions = [
    #"imageLiteral\(resourceName: "#,
    #"forResource: "#,
    #"SegmentedBarItemImageSet\("#,
    #"appendingPathComponent\("#,
    #"forKey: "#,
    #"userInfo\["#,
    #"UIImage\(named: "#,
    #"Animatiion: "#,
    #"animation: "#,
    #"withAnimation: "#,
    #"Animation.named\("#,
    #".animation\("#,
]*/
settings.swiftExceptions.forEach { exception in
    allSwiftStringPattern += #"(?<!("# + exception + #"))"#
}

allSwiftStringPattern += #"(?:"(?<KEY>(?!ic_)[_a-z0-9]*[_][a-z0-9]+)")*(?:"(?<ANYSTRING>\S*)")*"#

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

swiftFilePathSet.forEach { swiftFilePath in
    autoreleasepool {
        if let fileText = try? String(contentsOf: URL(fileURLWithPath: projectPath + "/" + swiftFilePath), encoding: .utf8) {
            matchingStrings(regex: swiftKeyPattern, text: fileText)
                .map { $0.first }
                .compactMap { $0 }
                .forEach { swiftKeys.insert($0) }

            matchingStrings(regex: swiftOldKeyPattern, text: fileText)
                .map { $0.first }
                .compactMap { $0 }
                .forEach { swiftKeys.insert($0) }

            if settings.allUntranslatedStrings {
                matchingStrings(regex: allSwiftStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                    .map { $0.first }
                    .compactMap { $0 }
                    .forEach { allSwiftStrings.insert($0) }
            }
            matchingStrings(regex: allSwiftStringPattern, text: fileText)
                .map { $0.first }
                .compactMap { $0 }
                .forEach { allProbablyKeys.insert($0) }
        }
    }
}

mFilePathSet.forEach { mFilePath in
    autoreleasepool {
        if let fileText = try? String(contentsOf: URL(fileURLWithPath: projectPath + "/" + mFilePath), encoding: .utf8) {
            matchingStrings(regex: objCKeyPattern, text: fileText)
                .map { $0.first }
                .compactMap { $0 }
                .forEach { mKeys.insert($0) }
            if settings.allUntranslatedStrings {
                matchingStrings(regex: allObjCStringPattern, text: fileText, names: [anyStringVariableCaptureName])
                    .map { $0.first }
                    .compactMap { $0 }
                    .forEach { allSwiftStrings.insert($0) }
            }
            matchingStrings(regex: allObjCStringPattern, text: fileText)
                .map { $0.first }
                .compactMap { $0 }
                .forEach { allProbablyKeys.insert($0) }
        }
    }
}

localizableFilePathDict.forEach { dirPath in
    autoreleasepool {
        let paath = (projectPath + "/" + dirPath + "/" + "Localizable.strings")
        do {
            // Koto utf8, Mono utf16
            let fileText8 = try? String(contentsOf: URL(fileURLWithPath: paath), encoding: .utf8)
            let fileText16 = try? String(contentsOf: URL(fileURLWithPath: paath), encoding: .utf16)
            let arr = [fileText8, fileText16].compactMap { $0 }

            if let fileText = arr.first {
                let element: [String: String] = matchingStrings(regex: localizedPairPattern, text: fileText, names: [keyVariableCaptureName, translationVariableCaptureName])
                    .map { (smallArray: [String]) -> [String: String] in
                        [smallArray.first ?? "": smallArray.last ?? ""]
                    }
                    .reduce([String: String]()) { (result: [String: String], value: [String: String]) in
                        var newDict = result
                        newDict[value.keys.first ?? ""] = value.values.first ?? ""

                        return newDict
                    }

                localizationsDict[dirPath] = element
            }
        }
    }
}

print(swiftKeys)
print(mKeys)

let combinedUsedLocalizedKeys = swiftKeys.union(mKeys)

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

/*
 Koto

 - "registration_limit_risk_decline_reason"
 - "registration_limit_installment_agreement"
 - "registration_limit_risk_decline_debit"

 Mono:
 - "categories"
 - "Messenger"
 - "Viber"
 - "number_payments"
 - "contacts"
 - "Telegram"
 - "A"
 - "more_about_info_processing_title"
 - ""
 - "Email"
 - "number_payments_two"
 - "monthes_amount"
 - "registration_foreign_passport_subtitle"
 */
