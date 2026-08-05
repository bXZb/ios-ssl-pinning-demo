import Foundation
import Alamofire
import TrustKit
import AFNetworking

@MainActor
class BaseHTTPRequest: Identifiable, ObservableObject {

    nonisolated let id = UUID()
    let name: String
    let url: String

    @Published var isLoading = false
    @Published var status: RequestStatus = .none

    // Why a failed request failed. Surfaced through the UI (see ContentView) as well as the
    // console, because UI tests run the app as a separate process and never see its stdout.
    @Published var diagnostics: String = ""

    init(name: String, url: String) {
        self.name = name
        self.url = url
    }

    func addDiagnostic(_ message: String) {
        print("\(name): \(message)")
        diagnostics += (diagnostics.isEmpty ? "" : " | ") + message
    }

    func run() async {
        URLCache.shared.removeAllCachedResponses()

        isLoading = true
        status = .none
        diagnostics = ""

        do {
            let statusCode = try await performRequest()

            if (statusCode != 200) {
                throw URLError(.badServerResponse)
            }

            status = .success
        } catch {
            addDiagnostic("failed with \(error)")
            status = .failure
        }

        isLoading = false
    }
    
    func performRequest() async throws -> Int {
        preconditionFailure("performRequest must be overloaded for each case")
    }
}

class SimpleHTTPRequest: BaseHTTPRequest {
    override func performRequest() async throws -> Int {
        let url = URL(string: url)!
        
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 10
        urlRequest.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData

        let session = buildSession()
        defer { session.finishTasksAndInvalidate() }

        let (_, response) = try await session.data(for: urlRequest)
        return (response as! HTTPURLResponse).statusCode
    }
    
    func buildSession() -> URLSession {
        return URLSession(configuration: .default)
    }
}

class URLSessionPinnedRequest: SimpleHTTPRequest {

    let pinnedKeyHashes: [String]

    init(name: String, url: String, pinnedKeyHashes: [String]) {
        self.pinnedKeyHashes = pinnedKeyHashes
        super.init(name: name, url: url)
    }

    override func buildSession() -> URLSession {
        let delegate = PinningURLSessionDelegate(
            pinnedKeyHashes: pinnedKeyHashes,
            onDiagnostic: { [weak self] message in
                Task { @MainActor in self?.addDiagnostic(message) }
            }
        )
        return URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
    }

}

class AlamofireBaseHTTPRequest: BaseHTTPRequest {
    
    let evaluators: [String: ServerTrustEvaluating]
    
    init(name: String, url: String, evaluators: [String: ServerTrustEvaluating]) {
        self.evaluators = evaluators
        super.init(name: name, url: url)
    }

    /// Alamofire keys its evaluators by host, which is the only part the pinned subclasses vary.
    static func evaluators(
        for url: String,
        _ evaluator: ServerTrustEvaluating
    ) -> [String: ServerTrustEvaluating] {
        return [URL(string: url)!.host!: evaluator]
    }
    
    override func performRequest() async throws -> Int {
        // Disable all caching:
        let configuration = URLSessionConfiguration.af.default
        configuration.urlCache = nil

        let session = Session(
            configuration: configuration,
            serverTrustManager: ServerTrustManager(
                allHostsMustBeEvaluated: !self.evaluators.isEmpty,
                evaluators: self.evaluators
            )
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(self.url).response { response in
                switch response.result {
                    case .success:
                        continuation.resume(returning: response.response!.statusCode)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                }
            }
        }
    }
}

class AlamofireSimpleHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String) {
        super.init(name: name, url: url, evaluators: [:])
    }
    
}

class AlamofirePinnedCertHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String, pinnedCertificates: [SecCertificate]) {
        // acceptSelfSignedCertificates would install these as the only trust anchors, so an
        // interception certificate would fail chain validation before the pin was ever compared.
        let evaluators = Self.evaluators(for: url, PinnedCertificatesTrustEvaluator(
            certificates: pinnedCertificates,
            acceptSelfSignedCertificates: false,
            performDefaultValidation: true,
            validateHost: true
        ))

        super.init(name: name, url: url, evaluators: evaluators)
    }
    
}

class AlamofirePinnedPKHTTPRequest: AlamofireBaseHTTPRequest {
    
    init(name: String, url: String, pinnedKeys: [SecKey]) {
        let evaluators = Self.evaluators(for: url, PublicKeysTrustEvaluator(
            keys: pinnedKeys,
            performDefaultValidation: true,
            validateHost: true
        ))

        super.init(name: name, url: url, evaluators: evaluators)
    }
    
}

class TrustKitPinnedHTTPRequest: SimpleHTTPRequest {
    
    init(name: String) {
        super.init(name: name, url: "https://\(TRUSTKIT_PINNED_HOST)")
    }

    // Runs once, on first use, without a mutable global to guard:
    private static let initializeTrustKit: Void = {
        TrustKit.initSharedInstance(withConfiguration: [
            kTSKSwizzleNetworkDelegates: false,
            kTSKEnforcePinning: true,
            kTSKPinnedDomains: [
                TRUSTKIT_PINNED_HOST: [
                    // TrustKit requires a backup pin, so we pin both the root and the
                    // intermediate rather than padding the list with a dud:
                    kTSKPublicKeyHashes: [
                        GTS_ROOT_R1_SPKI_SHA256,
                        GTS_INTERMEDIATE_SPKI_SHA256
                    ]
                ]
            ]
        ])
    }()

    override func buildSession() -> URLSession {
        _ = Self.initializeTrustKit

        return URLSession(
            configuration: .default,
            delegate: TrustKitURLSessionDelegate(),
            delegateQueue: nil
        )
    }
    
}

class AFNetworkingSimpleHTTPRequest: BaseHTTPRequest {
    
    override func performRequest() async throws -> Int {
        let manager = buildManager()
        
        return try await withCheckedThrowingContinuation { continuation in
            manager.get("/", parameters: nil, headers: nil, progress: nil, success: { (task, responseObject) in
                let httpResponse = task.response as! HTTPURLResponse
                continuation.resume(returning: httpResponse.statusCode)
            }, failure: { (task, error) in
                continuation.resume(throwing: error)
            })
        }
    }
    
    func buildManager() -> AFHTTPSessionManager {
        let manager = AFHTTPSessionManager(
            baseURL: URL(string: self.url)
        )
        manager.responseSerializer = AFHTTPResponseSerializer()
        return manager
    }

}

class AFNetworkingPinnedHTTPRequest: AFNetworkingSimpleHTTPRequest {
    
    let pinnedCertificates: [SecCertificate]

    init(name: String, url: String, pinnedCertificates: [SecCertificate]) {
        self.pinnedCertificates = pinnedCertificates
        super.init(name: name, url: url)
    }

    override func buildManager() -> AFHTTPSessionManager {
        let manager = super.buildManager()

        let securityPolicy = AFSecurityPolicy(pinningMode: .certificate)
        securityPolicy.pinnedCertificates = Set(
            self.pinnedCertificates.map { SecCertificateCopyData($0) } as! [Data]
        )
        securityPolicy.validatesDomainName = true
        manager.securityPolicy = securityPolicy

        return manager
    }

}
