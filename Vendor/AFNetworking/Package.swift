// swift-tools-version:5.0
//
//  Vendored AFNetworking 4.0.1 (ffae2391ab0c29dc88eb0a58d2f5b2c2c27cadbf).
//  Upstream is archived, so this tree is pinned locally.
//
//  Local change vs 4.0.1: remove `#import <netinet6/in6.h>` from
//  AFHTTPSessionManager.m and AFNetworkReachabilityManager.m. Xcode 26.4+
//  marks that header private in the Darwin module map; <netinet/in.h>
//  already provides the IPv6 types these files use.
//
//  Package.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import PackageDescription

let package = Package(name: "AFNetworking",
                      platforms: [.macOS(.v10_10),
                                  .iOS(.v9),
                                  .tvOS(.v9),
                                  .watchOS(.v2)],
                      products: [.library(name: "AFNetworking",
                                          targets: ["AFNetworking"])],
                      targets: [.target(name: "AFNetworking",
                                        path: "AFNetworking",
                                        publicHeadersPath: "")])
