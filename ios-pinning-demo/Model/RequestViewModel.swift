import Foundation

class RequestViewModel: ObservableObject {
    @Published var unpinnedRequests: [BaseHTTPRequest] = [
        SimpleHTTPRequest(name: "Plain HTTP", url: "http://\(UNPINNED_HOST)"),
        SimpleHTTPRequest(name: "HTTPS", url: "https://\(UNPINNED_HOST)"),
        AlamofireSimpleHTTPRequest(name: "Alamofire HTTPS", url: "https://\(UNPINNED_HOST)"),
        AFNetworkingSimpleHTTPRequest(name: "AFNetworking HTTPS", url: "https://\(UNPINNED_HOST)")
    ]

    @Published var pinnedRequests: [BaseHTTPRequest] = [
        // Pinned by ATS, in Info.plist:
        SimpleHTTPRequest(name: "Config-based pinning", url: "https://\(CONFIG_PINNED_HOST)"),

        URLSessionPinnedRequest(
            name: "URLSession pinning",
            url: "https://\(URLSESSION_PINNED_HOST)",
            pinnedKeyHashes: [
                GTS_ROOT_R1_RAW_KEY_SHA256,
                GTS_INTERMEDIATE_RAW_KEY_SHA256
            ]
        ),

        AlamofirePinnedCertHTTPRequest(
            name: "Alamofire cert pinning",
            url: "https://\(ALAMOFIRE_CERT_PINNED_HOST)",
            pinnedCertificates: BundledCertificates.publicChainCerts
        ),

        AlamofirePinnedPKHTTPRequest(
            name: "Alamofire PK pinning",
            url: "https://\(ALAMOFIRE_PK_PINNED_HOST)",
            pinnedKeys: BundledCertificates.publicChainCerts.map { SecCertificateCopyKey($0)! }
        ),

        AFNetworkingPinnedHTTPRequest(
            name: "AFNetworking cert pinning",
            url: "https://\(AFNETWORKING_PINNED_HOST)",
            pinnedCertificates: BundledCertificates.publicChainCerts
        ),

        TrustKitPinnedHTTPRequest(
            name: "TrustKit pinning"
            // TrustKit uses global configuration, configured to pin TRUSTKIT_PINNED_HOST
        )

        // ??? Webview pinning?
        // ??? CT libraries?
        // ??? Manual checks with SecTrustEvaulate / SecTrustSetAnchorCertificates - think covered by URLSession case?
        // ??? CFNetwork?
        // ??? NEF? Probably too low-level I think
    ]

    func sendRequest(_ httpRequest: BaseHTTPRequest) {
        Task {
            await httpRequest.run()
        }
    }
}

enum RequestStatus: CustomStringConvertible {
    case none, success, failure

    var description: String {
        switch self {
            case .none: return "pending"
            case .success: return "success"
            case .failure: return "failure"
        }
    }
}
