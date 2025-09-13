func foo() throws -> Int {
    try! nonThrowingCall()
    return 0
}