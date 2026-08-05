import Foundation

struct BundledCertificates {

    // The publicly trusted chain behind *.testserver.host, used by the evaluators that pin a
    // certificate rather than a key hash.
    //
    // Both the root and the intermediate, because a certificate pin only matches if that exact
    // certificate appears in the chain iOS built. The root is served cross-signed while the copy
    // in the trust store is self-signed, so which of the two terminates the chain isn't ours to
    // decide - but the intermediate is always in it either way.
    static let publicChainCerts: [SecCertificate] = [
        BundledCertificates.loadCertificate(filename: "gts-root-r1"),
        BundledCertificates.loadCertificate(filename: "gts-wr1")
    ]

    private static func loadCertificate(filename: String) -> SecCertificate {
        let filePath = Bundle.main.path(forResource: filename, ofType: "der")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!
        return certificate
    }
}
