[![Platform Linux](https://img.shields.io/badge/platform-linux-brightgreen.svg)](#)
[![Platform iOS macOS tvOS](https://img.shields.io/cocoapods/p/Socket.swift.svg?style=flat)](https://github.com/BiAtoms/Socket.swift)
[![Cocoapods Compatible](https://img.shields.io/cocoapods/v/Socket.swift.svg)](https://cocoapods.org/pods/Socket.swift)
[![Carthage Compatible](https://img.shields.io/badge/carthage-compatible-brightgreen.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/github/license/BiAtoms/Socket.swift.svg)](https://github.com/BiAtoms/Socket.swift/blob/master/LICENSE)
[![Build Status - Master](https://travis-ci.org/BiAtoms/Socket.swift.svg?branch=master)](https://travis-ci.org/BiAtoms/Socket.swift)

# Socket.swift

A POSIX socket wrapper written in swift.

## Features
 
- TLS/SSL support
- Linux, iOS, macOS and tvOS support
- Clean and understanable code


If you consider something needs to be implemented, just [open an issue](https://github.com/BiAtoms/Socket.swift/issues/new) or make a PR


## Example
```swift
let server = try Socket(.inet, type: .stream, protocol: .tcp) // create server socket
try server.set(option: .reuseAddress, true) // set SO_REUSEADDR to 1
try server.bind(port: 8090, address: nil) // bind 'localhost:8090' address to the socket
try server.listen() // allow incoming connections

let client = try Socket(.inet, type: .stream, protocol: .tcp) // create client socket
try client.connect(port: 8090) // connect to localhost:8090

let clientAtServerside = try server.accept() // accept client connection
 
let helloBytes = ([UInt8])("Hello World".utf8)
try clientAtServerside.write(helloBytes) // sending bytes to the client
clientAtServerside.close()

var buffer = [UInt8](repeating: 0, count: helloBytes.count) // allocate buffer
let numberOfReadBytes = try client.read(&buffer, size: helloBytes.count)
print(numberOfReadBytes == helloBytes.count) // true
print(buffer == helloBytes) // true

client.close()
server.close()
```

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate Socket.swift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
target '<Your Target Name>' do
pod 'Socket.swift', '~> 2.4.0'
end
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Socket.swift into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "BiAtoms/Socket.swift" ~> 2.4.0
```

Run `carthage update` to build the framework and drag the built `SocketSwift.framework` into your Xcode project.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but Socket.swift does support its use on supported platforms. 

Once you have your Swift package set up, adding Socket.swift as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/BiAtoms/Socket.swift.git", from: "2.4.0")
]
```

### Manually
Just drag and drop the files in the [Sources](https://github.com/BiAtoms/Socket.swift/blob/master/Sources) folder.

## Authors

* **Orkhan Alikhanov** - *Initial work* - [OrkhanAlikhanov](https://github.com/OrkhanAlikhanov)

See also the list of [contributors](https://github.com/BiAtoms/Socket.swift/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/BiAtoms/Socket.swift/blob/master/LICENSE) file for details
