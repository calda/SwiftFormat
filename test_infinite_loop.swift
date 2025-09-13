// Test case to reproduce infinite loop issue
import XCTest

final class TestCase: XCTestCase {
  func test_something() {
    let view = VariadicMultiView {
      ForEach(0..<2) { _ in
        Text("Test")
          .assertOnAppear(environment: \.testString, equals: "1")
          .fixEnvironmentBarrier()
          .assertOnAppear(
            environment: \.testString,
            equals: "",
            "Unfortunately this is empty instead of '1'. If this test ever fails, it means we can get rid of environment barrier fix.",
          )
      }
    } map: { children in
      ForEach(Array(children.enumerated()), id: \.offset) { _, child in
        child
          .assertOnAppear(environment: \.testString, equals: "1")
          .environment(\.testString, "1")
      }
    }
  }
}