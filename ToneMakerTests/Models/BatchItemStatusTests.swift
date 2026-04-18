import Testing
import Foundation
@testable import ToneMaker

struct BatchItemStatusTests {

    @Test func allCasesCount() {
        #expect(BatchItemStatus.allCases.count == 6)
    }

    @Test func rawValueRoundTrip() {
        for status in BatchItemStatus.allCases {
            let roundTripped = BatchItemStatus(rawValue: status.rawValue)
            #expect(roundTripped == status)
        }
    }

    @Test func isTerminalCorrectness() {
        #expect(BatchItemStatus.pending.isTerminal == false)
        #expect(BatchItemStatus.running.isTerminal == false)
        #expect(BatchItemStatus.completed.isTerminal == true)
        #expect(BatchItemStatus.failed.isTerminal == true)
        #expect(BatchItemStatus.cancelled.isTerminal == true)
        #expect(BatchItemStatus.skipped.isTerminal == true)
    }

    @Test func symbolNamesAreNonEmpty() {
        for status in BatchItemStatus.allCases {
            #expect(!status.symbolName.isEmpty)
        }
    }

    @Test func displayNamesAreNonEmpty() {
        for status in BatchItemStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }
}
