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
 - “usedKeys” -   “availableKeys” = ключи без перевода
 + “availableKeys” - “usedKeys”  =  неиспользуемые ключи
 + дублирование переводов

 */

let argCount = CommandLine.argc
let path = "/develop/DemoProjectForStringsSearch/DemoProjectForStringsSearch"
//    FileManager.default.currentDirectoryPath

// print(CommandLine.arguments)

let manager = FileManager.default
let enumerator = manager.enumerator(atPath: path)

var swiftSet = Set<String>()
var hSet = Set<String>()
var mSet = Set<String>()
var localizableDict = [String]()

// print(manager)

let content = try? manager.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath)
// print(content)

while let element = enumerator?.nextObject() as? String {
//    print(element)
    if element.hasSuffix(".swift") {
        swiftSet.insert(element)
    } else if element.hasSuffix(".h") {
        hSet.insert(element)
    } else if element.hasSuffix(".m") {
        mSet.insert(element)
    } else if element.hasSuffix(".lproj") {
        localizableDict.append(element)
    }
}

// print("swiftSet", swiftSet)
// print("hSet", hSet)
// print("mSet", mSet)

var swiftStrings = Set<String>()
var mStrings = Set<String>()
//                     [lang: [key: translation]
var localizedStrings = [String: [String: String]]()

let swiftPattern = #""(\S*)".localized\(\)"#
// lang(@"shake_find_devices")
let objCPattern = #"lang\(@"(\S*)"\)"#
let localizedStringPattern = #""(\S*)" = "(.*)";"#

// [0]  = whole regex result, we need only groups
func matchingStrings(regex: String, text: String, neededRegexGroups: [Int] = [1]) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }

    let nsText = text as NSString
    let results = regex.matches(in: text, options: [], range: NSMakeRange(0, text.count))
    dump(results)

    return results.map { result in
        neededRegexGroups.map {
            result.range(at: $0).location != NSNotFound
                ? nsText.substring(with: result.range(at: $0))
                : nil
        }
        .compactMap { $0 }
    }
}

swiftSet.forEach { swiftFilePath in
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + swiftFilePath), encoding: .utf8) {
        matchingStrings(regex: swiftPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { swiftStrings.insert($0) }
    }
}

mSet.forEach { mFilePath in
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + mFilePath), encoding: .utf8) {
        matchingStrings(regex: objCPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { mStrings.insert($0) }
    }
}

localizableDict.forEach { dirPath in
    let paath = path + "/" + dirPath + "/" + "Localizable.strings"
    print(paath)

    if let fileText = try? String(contentsOf: URL(fileURLWithPath: paath), encoding: .utf16) {
        let element: [String: String] = matchingStrings(regex: localizedStringPattern, text: fileText, neededRegexGroups: [1, 2])
            .map { (smallArray: [String]) -> [String: String] in
                [smallArray.first ?? "": smallArray.last ?? ""]
            }
            .reduce([String: String]()) { (result: [String: String], value: [String: String]) in
                var newDict = result
                newDict[value.keys.first ?? ""] = value.values.first ?? ""

                return newDict
            }
        localizedStrings[dirPath] = element
    }
}

print(swiftStrings)
print(mStrings)

print(localizedStrings)

let combinedUsedLocalizedStrings = swiftStrings.union(mStrings)

//          [lang: Set<key>]
let keysSet = localizedStrings.mapValues { Set($0.keys) }
let translationsSet = localizedStrings.mapValues { Set($0.values) }
let extraTranslations = keysSet.mapValues { $0.subtracting(combinedUsedLocalizedStrings) }

// let crossReference = Dictionary(grouping: contacts, by: { $0.phone })
let duplicatedTranslations = localizedStrings.mapValues { (oneLangDict: [String: String]) -> [String] in

    var valuesUsing = [String]()
    var extraKeys = [String]()

    oneLangDict.forEach { (arg: (key: String, value: String)) in
        let (key, value) = arg
        if valuesUsing.contains(value) {
            extraKeys.append(key)
        } else {
            valuesUsing.append(value)
        }
    }

    return extraKeys
}

print("\n\n")
print("extraTranslations", extraTranslations)
print("duplicatedTranslations", duplicatedTranslations)
