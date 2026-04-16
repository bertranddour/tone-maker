import Testing
import Foundation
@testable import ToneMaker

struct NAMMetadataReaderTests {

    // MARK: - Helpers

    private func writeTempJSON(_ json: [String: Any]) -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).nam")
        let data = try! JSONSerialization.data(withJSONObject: json)
        try! data.write(to: url)
        return url.path
    }

    // MARK: - Full Metadata

    @Test func readsFullMetadata() {
        let path = writeTempJSON([
            "version": "0.5.4",
            "metadata": [
                "name": "JCM800 Crunch",
                "modeled_by": "Bertrand",
                "gear_make": "Marshall",
                "gear_model": "JCM800",
                "gear_type": "amp",
                "tone_type": "crunch",
                "input_level_dbu": 7.4,
                "output_level_dbu": 23.1
            ]
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }

        let meta = NAMMetadataReader.readMetadata(from: path)
        #expect(meta != nil)
        #expect(meta?.name == "JCM800 Crunch")
        #expect(meta?.modeledBy == "Bertrand")
        #expect(meta?.gearMake == "Marshall")
        #expect(meta?.gearModel == "JCM800")
        #expect(meta?.gearType == "amp")
        #expect(meta?.toneType == "crunch")
        #expect(meta?.inputLevelDBu == 7.4)
        #expect(meta?.outputLevelDBu == 23.1)
    }

    // MARK: - Partial Metadata

    @Test func readsPartialMetadata() {
        let path = writeTempJSON([
            "metadata": [
                "name": "My Amp",
                "gear_type": "pedal"
            ]
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }

        let meta = NAMMetadataReader.readMetadata(from: path)
        #expect(meta?.name == "My Amp")
        #expect(meta?.gearType == "pedal")
        #expect(meta?.gearMake == nil)
        #expect(meta?.toneType == nil)
    }

    // MARK: - Empty Metadata

    @Test func returnsNilForEmptyMetadata() {
        let path = writeTempJSON([
            "metadata": [String: Any]()
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(NAMMetadataReader.readMetadata(from: path) == nil)
    }

    // MARK: - No Metadata Key

    @Test func returnsNilWhenNoMetadataKey() {
        let path = writeTempJSON([
            "version": "1.0",
            "weights": [1, 2, 3]
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(NAMMetadataReader.readMetadata(from: path) == nil)
    }

    // MARK: - Non-JSON File

    @Test func returnsNilForNonJSON() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).nam")
        try! Data("not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(NAMMetadataReader.readMetadata(from: url.path) == nil)
    }

    // MARK: - Missing File

    @Test func returnsNilForMissingFile() {
        #expect(NAMMetadataReader.readMetadata(from: "/nonexistent/path.nam") == nil)
    }

    // MARK: - Legacy user_metadata Key

    @Test func readsFromUserMetadataKey() {
        let path = writeTempJSON([
            "user_metadata": [
                "name": "Legacy Amp",
                "tone_type": "clean"
            ]
        ])
        defer { try? FileManager.default.removeItem(atPath: path) }

        let meta = NAMMetadataReader.readMetadata(from: path)
        #expect(meta?.name == "Legacy Amp")
        #expect(meta?.toneType == "clean")
    }
}
