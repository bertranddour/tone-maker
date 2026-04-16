import Testing
import Foundation
@testable import ToneMaker

struct ModelMetadataTests {

    // MARK: - Default Values

    @Test func defaultValuesCorrect() {
        let metadata = ModelMetadata()
        #expect(metadata.namName == nil)
        #expect(metadata.modeledBy == nil)
        #expect(metadata.gearMake == nil)
        #expect(metadata.gearModel == nil)
        #expect(metadata.gearType == .amp)
        #expect(metadata.toneType == .crunch)
        #expect(metadata.inputLevelDBu == nil)
        #expect(metadata.outputLevelDBu == nil)
    }

    // MARK: - Typed Enum Access

    @Test func gearTypeEnumRoundTrip() {
        let metadata = ModelMetadata()
        for gearType in GearType.allCases {
            metadata.gearType = gearType
            #expect(metadata.gearType == gearType)
            #expect(metadata.gearTypeRaw == gearType.rawValue)
        }
    }

    @Test func toneTypeEnumRoundTrip() {
        let metadata = ModelMetadata()
        for toneType in ToneType.allCases {
            metadata.toneType = toneType
            #expect(metadata.toneType == toneType)
            #expect(metadata.toneTypeRaw == toneType.rawValue)
        }
    }

    @Test func nilGearTypeHandling() {
        let metadata = ModelMetadata()
        metadata.gearType = .amp
        #expect(metadata.gearType == .amp)

        metadata.gearType = nil
        #expect(metadata.gearType == nil)
        #expect(metadata.gearTypeRaw == nil)
    }

    @Test func unknownGearTypeRawReturnsNil() {
        let metadata = ModelMetadata()
        metadata.gearTypeRaw = "invalid_gear"
        #expect(metadata.gearType == nil)
    }

    // MARK: - Has Content

    @Test func hasContentWhenFieldsSet() {
        let metadata = ModelMetadata()
        // Default metadata has gear type and tone type set, so hasContent is true
        #expect(metadata.hasContent == true)

        // Clearing all defaults
        metadata.gearType = nil
        metadata.toneType = nil
        #expect(metadata.hasContent == false)

        metadata.namName = "My Amp"
        #expect(metadata.hasContent == true)
    }

    @Test func hasContentWithGearType() {
        let metadata = ModelMetadata()
        metadata.gearType = .amp
        #expect(metadata.hasContent == true)
    }

    @Test func hasContentWithLevels() {
        let metadata = ModelMetadata()
        metadata.inputLevelDBu = 3.5
        #expect(metadata.hasContent == true)
    }

    // MARK: - Init with Parameters

    @Test func initWithAllParameters() {
        let metadata = ModelMetadata(
            namName: "JCM800 Crunch",
            modeledBy: "Bertrand",
            gearMake: "Marshall",
            gearModel: "JCM800",
            gearType: .amp,
            toneType: .crunch,
            inputLevelDBu: 3.5,
            outputLevelDBu: -2.0
        )

        #expect(metadata.namName == "JCM800 Crunch")
        #expect(metadata.modeledBy == "Bertrand")
        #expect(metadata.gearMake == "Marshall")
        #expect(metadata.gearModel == "JCM800")
        #expect(metadata.gearType == .amp)
        #expect(metadata.toneType == .crunch)
        #expect(metadata.inputLevelDBu == 3.5)
        #expect(metadata.outputLevelDBu == -2.0)
    }
}
