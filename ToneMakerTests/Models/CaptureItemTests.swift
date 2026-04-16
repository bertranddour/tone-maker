import Testing
import Foundation
@testable import ToneMaker

struct CaptureItemTests {

    // MARK: - Default Values

    @Test func defaultValuesCorrect() {
        let capture = CaptureItem()
        #expect(capture.name == "")
        #expect(capture.brand == "")
        #expect(capture.model == "")
        #expect(capture.modeledBy == "")
        #expect(capture.gearType == nil)
        #expect(capture.toneType == nil)
        #expect(capture.validationESR == nil)
        #expect(capture.modelFileName == "")
        #expect(capture.displayName == "Untitled Capture")
    }

    // MARK: - Typed Enum Access

    @Test func gearTypeRoundTrip() {
        let capture = CaptureItem()
        for gearType in GearType.allCases {
            capture.gearType = gearType
            #expect(capture.gearType == gearType)
            #expect(capture.gearTypeRaw == gearType.rawValue)
        }
    }

    @Test func toneTypeRoundTrip() {
        let capture = CaptureItem()
        for toneType in ToneType.allCases {
            capture.toneType = toneType
            #expect(capture.toneType == toneType)
            #expect(capture.toneTypeRaw == toneType.rawValue)
        }
    }

    @Test func architectureRoundTrip() {
        let capture = CaptureItem()
        capture.architecture = .lstm
        #expect(capture.architecture == .lstm)
        #expect(capture.architectureRaw == "LSTM")
    }

    // MARK: - ToneType Colors

    @Test func toneTypeColorsAssigned() {
        // Verify each tone type has a distinct color
        #expect(ToneType.clean.color != ToneType.crunch.color)
        #expect(ToneType.overdrive.color != ToneType.hiGain.color)
        #expect(ToneType.fuzz.color != ToneType.clean.color)
    }

    // MARK: - Display Name

    @Test func displayNameUsesNameWhenSet() {
        let capture = CaptureItem()
        capture.name = "JCM800 Crunch"
        #expect(capture.displayName == "JCM800 Crunch")
    }

    @Test func displayNameFallsBackWhenEmpty() {
        let capture = CaptureItem()
        capture.name = ""
        #expect(capture.displayName == "Untitled Capture")
    }
}
