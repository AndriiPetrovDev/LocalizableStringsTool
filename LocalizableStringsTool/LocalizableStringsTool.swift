//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

final class LocalizableStringsTool {
    let progressHelper = ProgressLogger()

    var swiftFilePathSet = Set<String>()
    var hFilePathSet = Set<String>()
    var mFilePathSet = Set<String>()
    var localizableFilePathArray = [String]()
    var localizableDictFilePathArray = [String]()

    let settingsFilePath = FilePathProvider.getSettingsFilePath()
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
    }

    private func getFilePaths() {
        FilePathProvider.getAllFilesPaths(settings: &settings,
                                          swiftFilePathSet: &swiftFilePathSet,
                                          hFilePathSet: &hFilePathSet,
                                          mFilePathSet: &mFilePathSet,
                                          localizableFilePathArray: &localizableFilePathArray,
                                          localizableDictFilePathArray: &localizableDictFilePathArray,
                                          progressHelper: progressHelper)
    }

    private func processFiles() {
        if settings.shouldAnalyzeSwift {
            taskGroup.enter()
            concurrentQueue.async { [self] in
                let swiftKeyPatterns = RegExpProvider.getSwiftKeyPatterns(settings: settings)
                let allSwiftStringPattern = RegExpProvider.getAllSwiftStringPattern(settings: settings)
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
                let objCKeyPattern = RegExpProvider.getObjCKeyPattern(settings: settings)
                let allObjCStringPattern = RegExpProvider.getAllObjCStringPattern(settings: settings)

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

        progressHelper.calculateConsumedTime()

        AnalysisResultProvider.printShort(result: result)

        AnalysisResultProvider.saveToFile(result: result, allStrings: Array(allStrings).sorted(), settingsFileFolder: settingsFileFolder)
    }
}
