import Testing
@testable import DevSweepCore

@Test func humanBytesDisplaysZeroAsZeroGB() {
    #expect(ByteFormat.humanBytes(0) == "0 GB")
}

@Test func humanBytesKeepsDecimalGigabyteFormattingForNonZeroValues() {
    #expect(ByteFormat.humanBytes(21_000_000_000) == "21 GB")
}
