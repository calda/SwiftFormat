func foo() throws -> Int {
    try! nonThrowingCall()
    try? anotherCall()
    return 0
}