//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

struct FilePathHelper {

    static func getAllFilesPaths(settings: Settings,
                                 swiftFilePathSet: inout Set<String>,
                                 hFilePathSet: inout Set<String>,
                                 mFilePathSet: inout Set<String>,
                                 localizableFilePathArray: inout [String],
                                 localizableDictFilePathArray: inout [String],
                                 progressHelper: ProgressHelper) {
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
            progressHelper.commonFilesCount = swiftFilePathSet.count + hFilePathSet.count + mFilePathSet.count + localizableFilePathArray.count + localizableDictFilePathArray.count
        }
    }

    static func getSettingsFilePath() -> String? {
        print(#"Enter "LocalizedStringsTool.plist" absolute path:"#)
        let path = readLine()
        if let path = path, !path.isEmpty {
            return path
        } else {
            return nil
        }
    }

}
