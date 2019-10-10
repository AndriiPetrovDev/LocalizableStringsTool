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
 + “usedKeys” -   “availableKeys” = ключи без перевода
 + “availableKeys” - “usedKeys”  =  неиспользуемые ключи
 + дублирование переводов
 - добавить все исключения из моно
 - поддержка обж с
 - указание пути
 - рефакторинг
 - кастомные правила для ключей
 - кастомные исключения

 */

let argCount = CommandLine.argc
//let path = "/Users/Shared/Relocated Items/Security/develop/MONOBANK/app-ios-client/Koto"
let path = "/Users/Shared/Relocated Items/Security/develop/MONOBANK/app-ios-client/Mono"

let manager = FileManager.default
let enumerator = manager.enumerator(atPath: path)

var swiftFilePathSet = Set<String>()
var hFilePathSet = Set<String>()
var mFilePathSet = Set<String>()
var localizableFilePathDict = [String]()

let content = try? manager.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath)
// print(content)

while let element = enumerator?.nextObject() as? String {
    if element.hasSuffix(".swift") {
        swiftFilePathSet.insert(element)
    } else if element.hasSuffix(".h") {
        hFilePathSet.insert(element)
    } else if element.hasSuffix(".m") {
        mFilePathSet.insert(element)
    } else if element.hasSuffix(".lproj"), !element.contains("Pods"), !element.contains("MiSnapSDK"), !element.contains("PresentationLayer") {
        localizableFilePathDict.append(element)
    }
}

// print("swiftSet", swiftSet)
// print("hSet", hSet)
// print("mSet", mSet)

var swiftStrings = Set<String>()
var mStrings = Set<String>()
var allSwiftStrings = Set<String>()
var allSwiftProbablyKeys = Set<String>()
//                     [lang: [key: translation]
var localizedStrings = [String: [String: String]]()

let swiftPattern = #""(?<KEY>\S*)".localized\(\)"#

let objCPattern = #"lang\(@"(?<KEY>\S*)"\)"#
let localizedStringPattern = #""(?<KEY>\S*)" = "(.*)\s?";"#

let allObjCtStringPattern = #"@"(?<KEY>\S*)""#

let allSwiftStringPattern = #"(?<!(forResource: ))(?<!(SegmentedBarItemImageSet\())(?<!(appendingPathComponent\())(?<!(forKey: ))(?<!(userInfo\[))(?<!(UIImage\(named: ))(?<!(Animatiion: ))(?<!(animation: ))(?<!(withAnimation: ))(?<!(Animation.named\())(?<!(#imageLiteral\(resourceName: ))(?:"(?<KEY>((?<!ic_)[a-z0-9]+[_])+[a-z0-9]+)")*(?:"(?<ANYSTRING>\S*)")*"#

// [0]  = whole regex result, we need only groups

func matchingStrings(regex: String, text: String, names: [String] = ["KEY"]) -> [[String]] {
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
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + swiftFilePath), encoding: .utf8) {
        matchingStrings(regex: swiftPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { swiftStrings.insert($0) }
        matchingStrings(regex: allSwiftStringPattern, text: fileText, names: ["ANYSTRING"]).map { $0.first }.compactMap { $0 }.forEach { allSwiftStrings.insert($0) }
        matchingStrings(regex: allSwiftStringPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { allSwiftProbablyKeys.insert($0) }
    }
}

mFilePathSet.forEach { mFilePath in
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + mFilePath), encoding: .utf8) {
        matchingStrings(regex: objCPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { mStrings.insert($0) }
//        matchingStrings(regex: allObjCtStringPattern, text: fileText).map { $0.first }.compactMap { $0 }.forEach { allSwiftStrings.insert($0) }
    }
}

localizableFilePathDict.forEach { dirPath in
    let paath = (path + "/" + dirPath + "/" + "Localizable.strings")
//        .replacingOccurrences(of: " ", with: "\\ ")
//        .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed)!
    print(paath)
    do {
        // Koto utf8, Mono utf16
          let fileText8 = try? String(contentsOf: URL(fileURLWithPath: paath), encoding: .utf8)
          let fileText16 = try? String(contentsOf: URL(fileURLWithPath: paath), encoding: .utf16)
        let arr = [fileText8, fileText16].compactMap { $0 }
        
        if let fileText = arr.first {
        let element: [String: String] = matchingStrings(regex: localizedStringPattern, text: fileText, names: ["KEY", "ANYSTRING"])
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

//print("localizedStrings = ", localizedStrings)

let combinedUsedLocalizedStrings = swiftStrings.union(mStrings)

//          [lang: Set<key>]
let keysSet = localizedStrings.mapValues { Set($0.keys) }
let translationsSet = localizedStrings.mapValues { Set($0.values) }

let strings1 = keysSet.mapValues { $0.subtracting(combinedUsedLocalizedStrings) }
print(strings1)
let extraTranslations = strings1.mapValues { $0.subtracting(allSwiftStrings) }

// let crossReference = Dictionary(grouping: contacts, by: { $0.phone })
let duplicatedTranslations = localizedStrings.mapValues { (oneLangDict: [String: String]) -> [String: [String]] in

    var valuesUsing = [String]()
    //               translation: keys
    var extraKeys = [String: [String]]()

    oneLangDict.forEach { (arg: (key: String, value: String)) in
        let (key, value) = arg
        if extraKeys[value] != nil {
            extraKeys[value]!.append(key)
        } else {
            extraKeys[value] = [key]
        }

//        if valuesUsing.contains(value) {
//            extraKeys.append(key)
//        } else {
//            valuesUsing.append(value)
//        }
    }

    return extraKeys.filter { _, value in value.count > 1 }
}

//print("\n\n")
//print("extraTranslations")
//dump(extraTranslations)
//print("duplicatedTranslations")
//dump(duplicatedTranslations)

//print("allSwiftStrings")
//dump(allSwiftStrings)

print("allSwiftProbablyKeys")
dump(allSwiftProbablyKeys)

print("keys without translation")
let keysWithoutTranslation = keysSet.mapValues { allSwiftProbablyKeys.subtracting($0) }

dump(keysWithoutTranslation)

