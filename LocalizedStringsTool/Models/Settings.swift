//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

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
