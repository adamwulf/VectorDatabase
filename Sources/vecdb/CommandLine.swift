//
//  main.swift
//  vecdb
//
//  Created by Adam Wulf on 6/4/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox
import USearch
import SQLite
import Logfmt
import VectorDatabase

enum Error: Swift.Error {
    case embeddingError
    case emptyInput
    case textAlreadyExists(key: UInt64)
    case notFound
    case searchError
}

@main
struct VecDB: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "vecdb",
        version: "VecDB",
        subcommands: [Store.self, Lookup.self, Search.self, Example.self]
    )
}

struct Example: AsyncParsableCommand {
    @Argument(help: "Optional location of the USearch database file")
    var dbPath: String?

    static var configuration = CommandConfiguration(
        commandName: "example",
        abstract: "Store a few words into the database, and then search for a novel vector to find similar words."
    )

    func run() async throws {
        let databasePath = resolveDBPath(dbPath)
        let vectorDB = try VectorDatabase(at: databasePath)

        // prime the database
        _ = try await vectorDB.insert(text: "king")
        _ = try await vectorDB.insert(text: "man")
        _ = try await vectorDB.insert(text: "woman")
        _ = try await vectorDB.insert(text: "queen")
        _ = try await vectorDB.insert(text: "duck")

        let king = try vectorDB.lookup(text: "king")
        let man = try vectorDB.lookup(text: "man")
        let woman = try vectorDB.lookup(text: "woman")

        let embedding = king.embedding - man.embedding + woman.embedding

        let results = try vectorDB.search(embedding: embedding, count: 10)
        let textResults = try results.map({ (text: try vectorDB.lookup(key: $0.key).text, distance: $0.distance) })
            .sorted(by: { $0.distance < $1.distance })
        print("\(textResults)")
    }
}

struct Search: AsyncParsableCommand {
    @Flag(name: [.short, .long], help: "Print verbose logs")
    var verbose: Bool = false

    @Argument(help: "Optional location of the USearch database file")
    var dbPath: String?

    @Option(help: "The text to search for the vector db")
    var text: String?

    @Option(help: "The number of results to return")
    var count: Int = 10

    static var configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search the database for closest matching words to the input text."
    )

    func run() async throws {
        let databasePath = resolveDBPath(dbPath)
        let vectorDB = try VectorDatabase(at: databasePath)

        var inputText = self.text
        if inputText == nil {
            inputText = readStdinToEnd() // Read from stdin if text is not provided
        }

        guard let text = inputText else {
            throw Error.emptyInput
        }

        let results = try vectorDB.search(text: text, count: count)
        let textResults = try results.map({ (text: try vectorDB.lookup(key: $0.key).text, distance: $0.distance) })
            .sorted(by: { $0.distance < $1.distance })
        print("\(textResults)")
    }
}

struct Lookup: AsyncParsableCommand {
    @Flag(name: [.short, .long], help: "Print verbose logs")
    var verbose: Bool = false

    @Argument(help: "Optional location of the USearch database file")
    var dbPath: String?

    @Option(help: "The text to search for the vector db")
    var text: String?

    @Option(help: "The number of results to return")
    var count: Int = 10

    static var configuration = CommandConfiguration(
        commandName: "lookup",
        abstract: "Lookup and print the embedding of the input text, if found"
    )

    func run() async throws {
        let databasePath = resolveDBPath(dbPath)
        let vectorDB = try VectorDatabase(at: databasePath)

        var inputText = self.text
        if inputText == nil {
            inputText = readStdinToEnd() // Read from stdin if text is not provided
        }

        guard let text = inputText else {
            throw Error.emptyInput
        }

        let embedding = try vectorDB.lookup(text: text)
        print("\(embedding)")
    }
}

struct Store: AsyncParsableCommand {

    @Flag(name: [.short, .long], help: "Print verbose logs")
    var verbose: Bool = false

    @Argument(help: "Optional location of the USearch database file")
    var dbPath: String?

    @Option(help: "The text to store into the vector db")
    var text: String?

    static var configuration = CommandConfiguration(
        commandName: "store",
        abstract: "Embed and store the input text into the database"
    )

    func run() async throws {
        let databasePath = resolveDBPath(dbPath)
        let vectorDB = try VectorDatabase(at: databasePath)

        var inputText = self.text
        if inputText == nil {
            inputText = readStdinToEnd() // Read from stdin if text is not provided
        }

        guard let text = inputText else {
            throw Error.emptyInput
        }

        let key = try await vectorDB.insert(text: text)
        print("\(key)")
    }
}

// MARK: - Private

enum LogLevel: String {
    case verbose
    case debug
    case info
    case warning
    case error
}

func log(_ logLevel: LogLevel, _ message: String, context: [String: Any]? = nil) {
    print("\(logLevel.rawValue) \(message) \(String.logfmt(context ?? [:]))")
}

func resolveDBPath(_ path: String?) -> String {
    let defaultFileName = "usearch.db"
    let fileManager = FileManager.default
    let currentDirectoryPath = fileManager.currentDirectoryPath

    guard let path = path else {
        return currentDirectoryPath + "/" + defaultFileName
    }

    let resolvedPath = (path as NSString).expandingTildeInPath

    var isDir: ObjCBool = false
    if fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDir) {
        if isDir.boolValue {
            return (resolvedPath as NSString).appendingPathComponent(defaultFileName)
        } else {
            return resolvedPath
        }
    }

    if resolvedPath.hasPrefix("/") {
        return resolvedPath
    } else {
        if resolvedPath.hasSuffix(".db") {
            return currentDirectoryPath + "/" + resolvedPath
        } else {
            return currentDirectoryPath + "/" + resolvedPath + ".db"
        }
    }
}

func readStdinToEnd() -> String? {
    if let input = readLine(strippingNewline: false) {
        var allInput = input
        while let line = readLine(strippingNewline: false) {
            allInput += line
        }
        return allInput
    }
    return nil
}
