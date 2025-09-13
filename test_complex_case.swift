// Complex test case
import XCTest

final class TestCase: XCTestCase {
  func test_environmentBarrier_onForEachInsideMultiWithMiddleZStackWrapper_itOvercomesBarrier() {
    let view = VariadicMultiView {
      ForEach(0..<2) { _ in
        ZStack {
          Text("Test")
            .assertOnAppear(environment: \.testString, equals: "1")
        }
      }
    } map: { children in
      ForEach(Array(children.enumerated()), id: \.offset) { _, child in
        child
          .assertOnAppear(environment: \.testString, equals: "1")
          .environment(\.testString, "1")
      }
    }

    view.forceRender()
    XCTAssertEqual(mockLoggingService.assertOrLogCallCount, 4)
    XCTAssertEqual(mockLoggingService.loggedAssertionMessages().count, 0)
  }

  func test_environmentBarrier_onForEachInsideUnary_itCreatesBarrier() {
    let view = VariadicUnaryView {
      ForEach(0..<2) { _ in
        Text("Test")
          .assertOnAppear(environment: \.testString, equals: "", "⛔️ This is undesirable behavior.")
      }
    } map: { children in
      ForEach(Array(children.enumerated()), id: \.offset) { _, child in
        child
          .assertOnAppear(environment: \.testString, equals: "1")
          .environment(\.testString, "1")
      }
    }

    view.forceRender()
    XCTAssertEqual(mockLoggingService.assertOrLogCallCount, 4)
    XCTAssertEqual(mockLoggingService.loggedAssertionMessages().count, 0)
  }
}