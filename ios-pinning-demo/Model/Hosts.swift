import Foundation

// Every button uses its own hostname, so that whatever blocks (or fails to block) a request is
// unambiguously the feature that button demonstrates, rather than another button's config or the
// platform defaults leaking across. This matters most for the two mechanisms configured by domain
// rather than in code - ATS pinning in Info.plist, and TrustKit - but we do it throughout so that
// a red button always points at one specific thing.
//
// The hostnames are combinations of testserver.host modifiers (see https://testserver.host). The
// modifiers themselves are irrelevant here - we only need distinct names that behave identically.
// They deliberately use combined modes that accept either protocol or TLS version, so that no HTTP
// stack can fail the handshake for reasons unrelated to pinning.

// No pinning at all - the baseline that everything else is compared against:
let UNPINNED_HOST = "testserver.host"

// Publicly trusted (Google Trust Services) hosts. Everything pinned in a library goes here, so
// that the system still trusts an interception certificate and the pin is the only thing that can
// reject it. Without that, these would fail while building the chain and would never exercise the
// pinning they exist to demonstrate.
let CONFIG_PINNED_HOST = "http1--http2--tls-v1-2--tls-v1-3.testserver.host"
let TRUSTKIT_PINNED_HOST = "http2--http1--tls-v1-2--tls-v1-3.testserver.host"
let ALAMOFIRE_CERT_PINNED_HOST = "http1--http2--tls-v1-3--tls-v1-2.testserver.host"
let ALAMOFIRE_PK_PINNED_HOST = "http2--http1--tls-v1-3--tls-v1-2.testserver.host"
let AFNETWORKING_PINNED_HOST = "tls-v1-2--tls-v1-3--http1--http2.testserver.host"
let URLSESSION_PINNED_HOST = "tls-v1-3--tls-v1-2--http1--http2.testserver.host"

// The Android demo points its hand-written pinning at testserver.host's own CA
// (rsa8192--untrusted-root), because a network security config can name an extra trust anchor.
// iOS has no equivalent: ATS evaluates the chain while connecting and fails the handshake before
// raising an authentication challenge, so a URLSession delegate never runs and cannot install an
// anchor of its own. Doing that here would need an ATS exception for the domain, which would then
// be the thing under test rather than the pinning - so this uses a public host like the rest.

// SHA-256 of the SubjectPublicKeyInfo, as used by TrustKit and by ATS in Info.plist. We pin the
// key rather than the certificate so that cross-signing a root (which changes the certificate but
// not the key) doesn't break the pins - that is precisely what broke the previous ISRG X1 pins.
let GTS_ROOT_R1_SPKI_SHA256 = "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc="
let GTS_INTERMEDIATE_SPKI_SHA256 = "yDu9og255NN5GEf+Bwa9rTrqFQ0EydZ0r1FCh9TdAW4="

// The same two keys again, but hashed as SecKeyCopyExternalRepresentation returns them (PKCS#1 for
// RSA) rather than as SPKI, which is what our own delegate compares against. Fiddly to format to
// match the pins above, but it keeps that delegate's code to just the Security APIs:
let GTS_ROOT_R1_RAW_KEY_SHA256 = "lK8IrGu+Yr3bnuiDnxi5kSkGkcCzXbJlG1jZi2pL6jg="
let GTS_INTERMEDIATE_RAW_KEY_SHA256 = "5mpRq06Sph4w206qGXO47chckkPuBmGBeXk+oIzKuF8="
