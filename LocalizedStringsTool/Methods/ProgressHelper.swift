//
// Created by Andrew Petrov on 29.07.2021.
// Copyright (c) 2021 AndrewPetrov. All rights reserved.
//

import Foundation

final class ProgressHelper {

    let startTime = Date()

    var commonFilesCount = 0
    var currentFilesCountHandled = 0

    func increaseProgress() {
        currentFilesCountHandled += 1

        let maxLength = 50
        var currentLength = (maxLength * currentFilesCountHandled) / commonFilesCount

        currentLength = max(0, currentLength)
        var progressString = ""
        for _ in 0 ..< currentLength {
            progressString += "■"
        }
        for _ in 0 ..< maxLength - currentLength {
            progressString += "□"
        }
        let resultString = String(format: "\u{1B}[1A\u{1B} %@ ", progressString)
        print(resultString)
    }

    func calculateConsumedTime() {
        let endTime = Date()
        let consumedTime = endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate
        print("consumed time: ", Int(consumedTime), "sec")

    }

}
