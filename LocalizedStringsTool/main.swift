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
 - получить список файлов .strings
 - составить массив из ключей “availableKeys” для каждого языка
 - “usedKeys” -   “availableKeys” = ключи без перевода
 - “availableKeys” - “usedKeys”  =  неиспользуемые ключи
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
    }
}

// print("swiftSet", swiftSet)
// print("hSet", hSet)
// print("mSet", mSet)

var swiftStrings = Set<String>()
var mStrings = Set<String>()

let swiftPattern = #""(\S*)".localized()"#
//lang(@"shake_find_devices")
let objCPattern =  #"lang\(@"(\S*)"\)"#

func matchingStrings(regex: String, text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }

    let nsText = text as NSString
    let results = regex.matches(in: text, options: [], range: NSMakeRange(0, text.count))

    return results.map { result in

        result.range(at: 1).location != NSNotFound
            ? nsText.substring(with: result.range(at: 1))
            : ""
    }
}

swiftSet.forEach { swiftFilePath in
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + swiftFilePath), encoding: .utf8) {
        matchingStrings(regex: swiftPattern, text: fileText).forEach { swiftStrings.insert($0) }
    }
}

mSet.forEach { mFilePath in
    if let fileText = try? String(contentsOf: URL(fileURLWithPath: path + "/" + mFilePath), encoding: .utf8) {
        matchingStrings(regex: objCPattern, text: fileText).forEach { mStrings.insert($0) }
    }
}

print(swiftStrings)
print(mStrings)
