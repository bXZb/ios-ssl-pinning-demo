import Foundation

struct BundledCertificates {

    // The publicly trusted chain behind *.testserver.host. We keep both the root and the
    // intermediate, and pin them by public key rather than by certificate, so that either being
    // rotated or cross-signed doesn't break the pins - which is exactly what broke the previous
    // Let's Encrypt ISRG X1 pins.
    static let gtsRootR1Cert: SecCertificate = BundledCertificates.loadCertificate(filename: "gts-root-r1")
    static let gtsIntermediateCert: SecCertificate = BundledCertificates.loadCertificate(filename: "gts-wr1")

    static let publicChainCerts: [SecCertificate] = [gtsRootR1Cert, gtsIntermediateCert]

    private static func loadCertificate(filename: String) -> SecCertificate {
        let filePath = Bundle.main.path(forResource: filename, ofType: "der")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)!
        return certificate
    }
}
