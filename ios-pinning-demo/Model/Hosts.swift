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

// Issued by testserver.host's own CA, which serves its root in the chain and doesn't rotate. iOS
// has no equivalent of Android's network security config, so this can only be used where we
// install that root as a trust anchor ourselves - i.e. our own URLSession delegate:
let URLSESSION_PINNED_HOST = "rsa8192--untrusted-root.testserver.host"

// SHA-256 of the SubjectPublicKeyInfo, as used by TrustKit and by ATS in Info.plist. We pin the
// key rather than the certificate so that cross-signing a root (which changes the certificate but
// not the key) doesn't break the pins - that is precisely what broke the previous ISRG X1 pins.
let GTS_ROOT_R1_SPKI_SHA256 = "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc="
let GTS_INTERMEDIATE_SPKI_SHA256 = "yDu9og255NN5GEf+Bwa9rTrqFQ0EydZ0r1FCh9TdAW4="

// SHA-256 of the raw key as SecKeyCopyExternalRepresentation returns it (PKCS#1 for RSA), which is
// what our own delegate compares against. Fiddly to format to match the pins above, but it keeps
// that delegate's code to just the Security APIs. Both the root and the intermediate, so that
// either one being rotated still leaves a valid pin:
let TESTSERVER_ROOT_RAW_KEY_SHA256 = "Xg2CpDrIW0Vni47R5mXbrsAi98KvuuzxhCaVyd//Vj4="
let TESTSERVER_INTERMEDIATE_RAW_KEY_SHA256 = "Xi1YcDF35CwFeuPLEAezmu0TX+JZcXK2rZXo21SUj/g="
