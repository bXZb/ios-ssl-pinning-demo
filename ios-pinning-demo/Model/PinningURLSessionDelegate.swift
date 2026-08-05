import Foundation
import CryptoKit

class PinningURLSessionDelegate: NSObject, URLSessionDelegate {
    var pinnedKeyHashes: [String]
    var extraAnchors: [SecCertificate]
    var onDiagnostic: (String) -> Void

    init(
        pinnedKeyHashes: [String],
        extraAnchors: [SecCertificate] = [],
        onDiagnostic: @escaping (String) -> Void = { print($0) }
    ) {
        self.pinnedKeyHashes = pinnedKeyHashes
        self.extraAnchors = extraAnchors
        self.onDiagnostic = onDiagnostic
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?
    ) -> Void) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if !extraAnchors.isEmpty {
            SecTrustSetAnchorCertificates(serverTrust, extraAnchors as CFArray)
            // Keep the system anchors trusted alongside ours. Otherwise an interception
            // certificate is rejected while building the chain, and the pin check below - the
            // thing this class exists to demonstrate - never runs at all.
            SecTrustSetAnchorCertificatesOnly(serverTrust, false)
        }

        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            onDiagnostic("chain validation failed: \(trustError.map { String(describing: $0) } ?? "unknown")")

            // Distinguish "our anchor was ignored" from "the chain is unacceptable regardless":
            // if trusting only our anchor succeeds, then keeping the system anchors alongside is
            // what's rejecting this, rather than anything about the certificate itself.
            if !extraAnchors.isEmpty {
                SecTrustSetAnchorCertificatesOnly(serverTrust, true)
                let anchorsOnlyWorks = SecTrustEvaluateWithError(serverTrust, nil)
                onDiagnostic("with anchorCertificatesOnly=true it \(anchorsOnlyWorks ? "SUCCEEDS" : "still fails")")
            }

            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            onDiagnostic("could not read the validated certificate chain")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Walk from the anchor down to the leaf. A pinned CA then matches before we ever try to
        // export the leaf's key, which matters because not every key is exportable - see below.
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
