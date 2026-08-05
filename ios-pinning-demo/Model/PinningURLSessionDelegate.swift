import Foundation
import CryptoKit

// Pinning done by hand, against the public key of any certificate in the chain.
//
// Note that this only works against a publicly trusted host. ATS evaluates the chain while
// establishing the connection, and for a chain it doesn't trust it fails the handshake outright
// without ever raising an authentication challenge - so a delegate like this never runs, and
// cannot be used to trust a private CA. Doing that on iOS requires an ATS exception for the
// domain, unlike Android, where the network security config can name an extra trust anchor.

class PinningURLSessionDelegate: NSObject, URLSessionDelegate {
    var pinnedKeyHashes: [String]
    var onDiagnostic: (String) -> Void

    init(
        pinnedKeyHashes: [String],
        onDiagnostic: @escaping (String) -> Void = { print($0) }
    ) {
        self.pinnedKeyHashes = pinnedKeyHashes
        self.onDiagnostic = onDiagnostic
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?
    ) -> Void) {
        // Logged so that a failure without this line is recognisable as "we were never asked",
        // which is what an ATS rejection looks like from in here:
        onDiagnostic("server trust challenge received")

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            onDiagnostic("challenge carried no server trust")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            onDiagnostic("chain validation failed: \(trustError.map { String(describing: $0) } ?? "unknown")")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            onDiagnostic("could not read the validated certificate chain")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Walk from the anchor down to the leaf, so a pinned CA matches before we try to export
        // the leaf's key - not every key is exportable, see hashPublicKey below.
        for serverCertificate in certificateChain.reversed() {
            guard let publicKeyHash = hashPublicKey(of: serverCertificate) else { continue }

            if pinnedKeyHashes.contains(publicKeyHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        onDiagnostic("no pinned key in chain of \(certificateChain.count): " +
                     certificateChain.map { hashPublicKey(of: $0) ?? "<unreadable>" }.joined(separator: ", "))
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// SHA-256 of the key as SecKeyCopyExternalRepresentation returns it (PKCS#1 for RSA).
    /// Returns nil rather than throwing: a key we can't read is just one we can't match against,
    /// and skipping it must not abandon the rest of the chain.
    private func hashPublicKey(of certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            onDiagnostic("could not read public key from certificate")
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            onDiagnostic("could not export public key: \(error!.takeRetainedValue() as Error)")
            return nil
        }

        return Data(SHA256.hash(data: publicKeyData)).base64EncodedString()
    }
}
