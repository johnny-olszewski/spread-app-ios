import Testing
@testable import JohnnyOFoundationCore

struct JohnnyOFoundationCoreTests {
    @Test func testPackageNamespace() {
        #expect(JohnnyOFoundationCoreNamespace.packageName == "johnnyo-foundation")
        #expect(JohnnyOFoundationCoreNamespace.packageVersion == 1)
    }
}
