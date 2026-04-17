import Testing
@testable import JohnnyOFoundationUI

struct JohnnyOFoundationUITests {
    @Test func testUINamespaceMirrorsPackageName() {
        #expect(JohnnyOFoundationUINamespace.packageName == "johnnyo-foundation")
    }
}
