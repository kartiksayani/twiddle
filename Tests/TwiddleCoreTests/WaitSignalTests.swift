import Foundation
import Testing
import TwiddleCore

struct WaitSignalTests {
  @Test func exactDone() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://done"))) == .done)
  }

  @Test func trailingSlash() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://done/"))) == nil)
  }

  @Test func path() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://done/x"))) == nil)
  }

  @Test func query() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://done?x=1"))) == nil)
  }

  @Test func fragment() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://done#x"))) == nil)
  }

  @Test func otherHost() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle://other"))) == nil)
  }

  @Test func opaqueURL() throws {
    #expect(WaitSignal(url: try #require(URL(string: "twiddle:done"))) == nil)
  }

  @Test func otherScheme() throws {
    #expect(WaitSignal(url: try #require(URL(string: "other://done"))) == nil)
  }

  @Test func schemeCaseIsPreservedAndRejected() throws {
    let url = try #require(URL(string: "TWIDDLE://done"))
    #expect(url.scheme == "TWIDDLE")
    #expect(WaitSignal(url: url) == nil)
  }

  @Test(arguments: [
    "twiddle://done?", "twiddle://done#", "twiddle://DONE", "twiddle://user@done",
    "twiddle://done:80", "twiddle://%64one", "twiddle://done/..",
  ])
  func otherNonExactURLs(value: String) throws {
    #expect(WaitSignal(url: try #require(URL(string: value))) == nil)
  }
}
