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

// Every pinned host below is publicly trusted (Google Trust Services), so that the system still
// trusts an interception certificate and the pin is the only thing that can reject it. Otherwise
// these would fail while building the chain, and would never exercise the pinning they exist to
// demonstrate.
let CONFIG_PINNED_HOST = "http1--http2--tls-v1-2--tls-v1-3.testserver.host"
let TRUSTKIT_PINNED_HOST = "http2--http1--tls-v1-2--tls-v1-3.testserver.host"
let ALAMOFIRE_CERT_PINNED_HOST = "http1--http2--tls-v1-3--tls-v1-2.testserver.host"
let ALAMOFIRE_PK_PINNED_HOST = "http2--http1--tls-v1-3--tls-v1-2.testserver.host"
let AFNETWORKING_PINNED_HOST = "tls-v1-2--tls-v1-3--http1--http2.testserver.host"
let URLSESSION_PINNED_HOST = "tls-v1-3--tls-v1-2--http1--http2.testserver.host"

// SHA-256 of the SubjectPublicKeyInfo, as used by TrustKit. ATS needs the same two values, but a
// plist can't reference these, so they're repeated in Info.plist and must be changed in both.
let GTS_ROOT_R1_SPKI_SHA256 = "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc="
let GTS_INTERMEDIATE_SPKI_SHA256 = "yDu9og255NN5GEf+Bwa9rTrqFQ0EydZ0r1FCh9TdAW4="

// The same two keys again, but hashed as SecKeyCopyExternalRepresentation returns them (PKCS#1 for
// RSA) rather than as SPKI, which is what our own delegate compares against.
let GTS_ROOT_R1_RAW_KEY_SHA256 = "lK8IrGu+Yr3bnuiDnxi5kSkGkcCzXbJlG1jZi2pL6jg="
let GTS_INTERMEDIATE_RAW_KEY_SHA256 = "5mpRq06Sph4w206qGXO47chckkPuBmGBeXk+oIzKuF8="
