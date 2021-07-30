//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

struct Translation {
    let key: String
    let value: String
}

struct Section {
    let name: String
    var translations: [Translation]
}

struct TranslationKeysDiff {
    let firstLangName: String
    let secondLangName: String
    let firstAddedKeys: [String]
    let firstDeletedKeys: [String]
}

struct AnalysisResult {
    //                       lang
    let unusedTranslations: [String: [Section]]
    //                     lang
    let untranslatedKeys: [String: Set<String>]
    //                           lang  translation  keys
    let translationDuplication: [String: [String: [String]]]
    let allUntranslatedStrings: [String]?
    let differentKeysInTranslations: [TranslationKeysDiff]
}
