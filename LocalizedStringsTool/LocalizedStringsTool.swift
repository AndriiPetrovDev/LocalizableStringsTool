//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

final class LocalizedStringsTool {
    let progressHelper = ProgressHelper()

    var swiftFilePathSet = Set<String>()
    var hFilePathSet = Set<String>()
    var mFilePathSet = Set<String>()
    var localizableFilePathArray = [String]()
    var localizableDictFilePathArray = [String]()

    let settingsFilePath = FilePathHelper.getSettingsFilePath()
    var settingsFileFolder: String = ""
    lazy var settings: Settings = {
        FileProcessor.readPlist(settingsFilePath: settingsFilePath, settingsFileFolder: &settingsFileFolder)
    }()

    var swiftKeys = Set<String>()
    var objCKeys = Set<String>()
    var allStrings = Set<String>()
    var allProbablyKeys = Set<String>()

    //                      language
    var localizationsDict = [String: [Section]]()
    var availableKeys = [String: Set<String>]()

    let concurrentQueue = DispatchQueue(label: "concurrentQueue", attributes: .concurrent)
    let syncQueue = DispatchQueue(label: "Atomic serial queue")
    let taskGroup = DispatchGroup()

    func runAnalysis() {
        getFilePaths()
        processFiles()
        getResult()
        progressHelper.calculateConsumedTime()
    }

    private func getFilePaths() {
        FilePathHelper.getAllFilesPaths(settings: settings,
                                        swiftFilePathSet: &swiftFilePathSet,
                                        hFilePathSet: &hFilePathSet,
                                        mFilePathSet: &mFilePathSet,
                                        localizableFilePathArray: &localizableFilePathArray,
                                        localizableDictFilePathArray: &localizableDictFilePathArray,
                                        progressHelper: progressHelper
        )
    }

    private func processFiles() {
        if settings.shouldAnalyzeSwift {
            taskGroup.enter()
            concurrentQueue.async { [self] in
                let swiftKeyPatterns = RegExpHelper.getSwiftKeyPatterns(settings: settings)
                let allSwiftStringPattern = RegExpHelper.getAllSwiftStringPattern(settings: settings)
                FileProcessor.processSwiftFiles(settings: settings,
                                                swiftKeyPatterns: swiftKeyPatterns,
                                                allSwiftStringPattern: allSwiftStringPattern,
                                                swiftFilePathSet: swiftFilePathSet,
                                                swiftKeys: &swiftKeys,
                                                allStrings: &allStrings,
                                                allProbablyKeys: &allProbablyKeys,
                                                syncQueue: syncQueue,
                                                parentTaskGroup: taskGroup,
                                                progressHelper: progressHelper)
            }
        }
        if settings.shouldAnalyzeObjC {
            taskGroup.enter()
            concurrentQueue.async { [self] in
                let objCFilePathSet = mFilePathSet.union(hFilePathSet)
                let objCKeyPattern = RegExpHelper.getObjCKeyPattern(settings: settings)
                let allObjCStringPattern = RegExpHelper.getAllObjCStringPattern(settings: settings)

                FileProcessor.processObjCFiles(settings: settings,
                                               objCKeyPattern: objCKeyPattern,
                                               allObjCStringPattern: allObjCStringPattern,
                                               objCFilePathSet: objCFilePathSet,
                                               objCKeys: &objCKeys,
                                               allStrings: &allStrings,
                                               allProbablyKeys: &allProbablyKeys,
                                               syncQueue: syncQueue,
                                               parentTaskGroup: taskGroup,
                                               progressHelper: progressHelper)
            }
        }

        taskGroup.enter()
        concurrentQueue.async { [self] in
            FileProcessor.processLocalizableFiles(settings: settings,
                                                  localizableFilePathDict: localizableFilePathArray,
                                                  localizationsDict: &localizationsDict,
                                                  availableKeys: &availableKeys,
                                                  syncQueue: syncQueue,
                                                  parentTaskGroup: taskGroup,
                                                  progressHelper: progressHelper)
        }

        taskGroup.enter()
        concurrentQueue.async { [self] in
            FileProcessor.processLocalizableDictFiles(settings: settings,
                                                      localizableDictFilePathDict: localizableDictFilePathArray,
                                                      availableKeys: &availableKeys,
                                                      syncQueue: syncQueue,
                                                      parentTaskGroup: taskGroup,
                                                      progressHelper: progressHelper)
        }

        taskGroup.wait()
    }

    private func getResult() {
        let result = AnalysisResultProvider.getAnalysisResult(
            settings: settings,
            swiftKeys: swiftKeys,
            objCKeys: objCKeys,
            availableKeys: availableKeys,
            syncQueue: syncQueue,
            localizationsDict: localizationsDict
        )
        AnalysisResultProvider.printShort(result: result)

        AnalysisResultProvider.saveToFile(result: result, settingsFileFolder: settingsFileFolder)
    }

}
