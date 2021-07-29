//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

struct Settings: Decodable {
    var projectRootFolderPath: String

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
    let excludedUntranslatedKeys: [String]
    let excludedUnusedKeys: [String]
    let swiftPatternPrefixExceptions: [String]
    let objCPatternPrefixExceptions: [String]
    let excludedFoldersNameComponents: [String]
}
