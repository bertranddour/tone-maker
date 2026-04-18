import Testing
import Foundation
@testable import ToneMaker

struct TrainingMetricTests {

    @Test func storesEpochAndLoss() {
        let metric = TrainingMetric(epoch: 42, valLoss: 0.001234)
        #expect(metric.epoch == 42)
        #expect(metric.valLoss == 0.001234)
    }

    @Test func codableRoundTrip() throws {
        let original = TrainingMetric(epoch: 7, valLoss: 0.0876)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TrainingMetric.self, from: data)
        #expect(decoded == original)
    }

    @Test func codableArrayRoundTrip() throws {
        let original = [
            TrainingMetric(epoch: 1, valLoss: 0.5),
            TrainingMetric(epoch: 2, valLoss: 0.25),
            TrainingMetric(epoch: 3, valLoss: 0.125),
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([TrainingMetric].self, from: data)
        #expect(decoded == original)
    }

    @Test func hashableUsableInSet() {
        let a = TrainingMetric(epoch: 1, valLoss: 0.5)
        let b = TrainingMetric(epoch: 1, valLoss: 0.5)
        let c = TrainingMetric(epoch: 2, valLoss: 0.5)
        let set: Set<TrainingMetric> = [a, b, c]
        #expect(set.count == 2)
    }
}
