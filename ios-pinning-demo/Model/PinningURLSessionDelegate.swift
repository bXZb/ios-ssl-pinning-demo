import Foundation
import CryptoKit

// Pinning done by hand, against the public key of any certificate in the chain. Only works
// against a publicly trusted host.

class PinningURLSessionDelegate: NSObject, URLSessionDelegate {
    let pinnedKeyHashes: [String]
    let onDiagnostic: (String) -> Void

    init(pinnedKeyHashes: [String], onDiagnostic: @escaping (String) -> Void) {
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
        var chainHashes: [String] = []

        for serverCertificate in certificateChain.reversed() {
            guard let publicKeyHash = hashPublicKey(of: serverCertificate) else {
                chainHashes.append("<unreadable>")
                continue
            }

            if pinnedKeyHashes.contains(publicKeyHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }

            chainHashes.append(publicKeyHash)
        }

        onDiagnostic("no pinned key in chain of \(certificateChain.count): " +
                     chainHashes.joined(separator: ", "))
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
