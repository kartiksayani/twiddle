import Foundation
import Testing
import TwiddleCore

struct AtomicStoreTests {
  @Test func interruptedWriteKeepsCompleteOldOrNewState() throws {
    let environmentKey = "TWIDDLE_ATOMIC_TEST_DIRECTORY"
    let instant = Date(timeIntervalSince1970: 1_793_318_400)
    let childDirectory = ProcessInfo.processInfo.environment[environmentKey]
    let directory =
      childDirectory.map { URL(fileURLWithPath: $0) }
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = Store(directory: directory, currentDate: { instant })
    let old = Store.State(date: store.today)
    var new = old
    new.seenIntro = true
    new.resume["words"] = .init(
      session: TypingSession(text: String(repeating: "word ", count: 50_000)))

    if childDirectory != nil {
      for _ in 0..<100 { try store.save(new) }
      return
    }

    try store.save(old)
    defer { try! FileManager.default.removeItem(at: directory) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    let bundleArgument = try #require(CommandLine.arguments.firstIndex(of: "--test-bundle-path"))
    process.arguments = [
      "--test-bundle-path", CommandLine.arguments[bundleArgument + 1],
      "--testing-library", "swift-testing", "--filter",
      "interruptedWriteKeepsCompleteOldOrNewState",
    ]
    var environment = ProcessInfo.processInfo.environment
    environment[environmentKey] = directory.path
    environment["LLVM_PROFILE_FILE"] = directory.appendingPathComponent("child.profraw").path
    process.environment = environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    defer {
      if process.isRunning {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
    }

    let deadline = Date().addingTimeInterval(15)
    var observedStagingFile = false
    while process.isRunning && Date() < deadline {
      let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      if files.contains(where: { $0 != "state.json" && $0 != "child.profraw" }) {
        observedStagingFile = true
        break
      }
      usleep(100)
    }
    // Stop the real Store writer as soon as its atomic replacement is staged.
    kill(process.processIdentifier, SIGKILL)
    process.waitUntilExit()
    #expect(observedStagingFile)
    #expect(process.terminationReason == .uncaughtSignal)
    #expect(process.terminationStatus == SIGKILL)
    let result = store.load()
    #expect(result.errors.isEmpty)
    #expect(result.state == old || result.state == new)
  }
}
