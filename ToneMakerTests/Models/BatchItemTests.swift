import Testing
import Foundation
@testable import ToneMaker

struct BatchItemTests {

    // MARK: - Defaults

    @Test func defaultValues() {
        let item = BatchItem()
        #expect(item.order == 0)
        #expect(item.outputFileName == "")
        #expect(item.captureName == "")
        #expect(item.status == .pending)
        #expect(item.validationESR == nil)
        #expect(item.calibratedLatency == nil)
        #expect(item.outputModelPath == nil)
        #expect(item.comparisonPlotPath == nil)
        #expect(item.errorMessage == nil)
        #expect(item.startedAt == nil)
        #expect(item.completedAt == nil)
        #expect(item.session == nil)
        #expect(item.capture == nil)
        #expect(item.persistedOutputFile == nil)
        #expect(item.lossCurve.isEmpty)
    }

    // MARK: - Loss Curve

    @Test func lossCurveAppendsInOrder() {
        let item = BatchItem()
        item.lossCurve.append(TrainingMetric(epoch: 1, valLoss: 0.5))
        item.lossCurve.append(TrainingMetric(epoch: 2, valLoss: 0.25))
        item.lossCurve.append(TrainingMetric(epoch: 3, valLoss: 0.125))
        #expect(item.lossCurve.count == 3)
        #expect(item.lossCurve.map(\.epoch) == [1, 2, 3])
        #expect(item.lossCurve.last?.valLoss == 0.125)
    }

    @Test func customInit() {
        let id = UUID()
        let item = BatchItem(id: id, order: 3, outputFileName: "amp.wav", captureName: "Mesa Crunch")
        #expect(item.id == id)
        #expect(item.order == 3)
        #expect(item.outputFileName == "amp.wav")
        #expect(item.captureName == "Mesa Crunch")
    }

    // MARK: - Status Round Trip

    @Test func statusEnumRoundTrip() {
        let item = BatchItem()
        for status in BatchItemStatus.allCases {
            item.status = status
            #expect(item.statusRaw == status.rawValue)
            #expect(item.status == status)
        }
    }

    @Test func unknownStatusRawFallsBackToPending() {
        let item = BatchItem()
        item.statusRaw = "junk"
        #expect(item.status == .pending)
    }

    // MARK: - Display Name

    @Test func displayNamePrefersCaptureName() {
        let item = BatchItem(order: 0, outputFileName: "amp.wav", captureName: "Custom Name")
        #expect(item.displayName == "Custom Name")
    }

    @Test func displayNameStripsWavExtensionFromFilename() {
        let item = BatchItem(order: 0, outputFileName: "amp_clean.wav")
        #expect(item.displayName == "amp_clean")
    }

    @Test func displayNameCaseInsensitiveExtensionStrip() {
        let item = BatchItem(order: 0, outputFileName: "amp.WAV")
        #expect(item.displayName == "amp")
    }

    @Test func displayNameFallsBackToUntitled() {
        let item = BatchItem()
        #expect(item.displayName == "Untitled Item")
    }
}
