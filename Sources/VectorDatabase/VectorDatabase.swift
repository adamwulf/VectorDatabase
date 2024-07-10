//
//  VectorDatabase.swift
//  vecdb
//
//  Created by Adam Wulf on 6/4/24.
//

import Foundation
import SwiftToolbox
import USearch
import SQLite
import NaturalLanguage

public class VectorDatabase {

    public enum Error: Swift.Error {
        case embeddingError
        case notFound
        case searchError
    }

    private let vectorDBPath: String
    private let sqliteDBPath: String
    private let textDB: Connection
    private let textsTable = Table("texts")
    private let idColumn = Expression<Int64>("id")
    private let textColumn = Expression<String>("text")
    private let vectorColumn = Expression<Blob>("vector")
    private let vectorDB: USearchIndex
    private let embeddingLanguage = NLEmbedding.wordEmbedding(for: .english)!

    public init(at path: String) throws {
        self.vectorDBPath = path
        self.sqliteDBPath = URL(filePath: path).deletingPathExtension().appendingPathExtension("sqlite").path(percentEncoded: false)

        // Initialize SQLite database
        self.textDB = try Connection(sqliteDBPath)

        // Initialize USearch database
        self.vectorDB = USearchIndex.make(
            metric: .cos,
            dimensions: UInt32(embeddingLanguage.dimension),
            connectivity: 8,
            quantization: USearchScalar.F64
        )

        // load the databases
        try textDB.run(textsTable.create(ifNotExists: true) { t in
            t.column(idColumn, primaryKey: .autoincrement)
            t.column(textColumn, unique: true)
            t.column(vectorColumn)
        })

        if FileManager.default.fileExists(atPath: vectorDBPath) {
            vectorDB.load(path: vectorDBPath)
        }
    }

    public func lookup(text: String) throws -> (text: String, embedding: [Double]) {
        guard let row = try textDB.pluck(textsTable.filter(textColumn == text)) else {
            throw Error.notFound
        }

        let text = row[textColumn]
        let vectorBlob = row[vectorColumn]
        let vectorData = Data(bytes: vectorBlob.bytes, count: vectorBlob.bytes.count)
        let vectorCount = vectorData.count / MemoryLayout<Double>.size
        var vector = [Double](repeating: 0, count: vectorCount)

        vectorData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            for i in 0..<vectorCount {
                let value = pointer.load(fromByteOffset: i * MemoryLayout<Double>.size, as: Double.self)
                vector[i] = Double(bitPattern: value.bitPattern)
            }
        }

        return (text: text, embedding: vector)
    }

    public func lookup(key: USearchKey) throws -> (text: String, embedding: [Double]) {
        guard let row = try textDB.pluck(textsTable.filter(idColumn == Int64(key))) else {
            throw Error.notFound
        }

        let text = row[textColumn]
        let vectorBlob = row[vectorColumn]
        let vectorData = Data(bytes: vectorBlob.bytes, count: vectorBlob.bytes.count)
        let vectorCount = vectorData.count / MemoryLayout<Double>.size
        var vector = [Double](repeating: 0, count: vectorCount)

        vectorData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            for i in 0..<vectorCount {
                let value = pointer.load(fromByteOffset: i * MemoryLayout<Double>.size, as: Double.self)
                vector[i] = Double(bitPattern: value.bitPattern)
            }
        }

        return (text: text, embedding: vector)
    }

    public func search(text: String, count: Int) throws -> [(key: USearchKey, distance: Float)] {
        let result = try lookup(text: text)
        let results = vectorDB.search(vector: result.embedding, count: count)

        var ret: [(key: USearchKey, distance: Float)] = []
        guard results.0.count == results.1.count else {
            throw Error.searchError
        }
        for index in results.0.indices {
            let key = results.0[index]
            let distance = results.1[index]
            ret.append((key: key, distance: distance))
        }

        return ret
    }

    public func search(embedding: [Double], count: Int) throws -> [(key: USearchKey, distance: Float)] {
        let results = vectorDB.search(vector: embedding, count: count)

        var ret: [(key: USearchKey, distance: Float)] = []
        guard results.0.count == results.1.count else {
            throw Error.searchError
        }
        for index in results.0.indices {
            let key = results.0[index]
            let distance = results.1[index]
            ret.append((key: key, distance: distance))
        }

        return ret
    }

    public func insert(text: String) async throws -> USearchKey {
        // Lookup or insert text
        if let existingText = try textDB.pluck(textsTable.filter(textColumn == text)) {
            let key = UInt64(existingText[idColumn])
            return key
        }

        guard let embedding = embeddingLanguage.vector(for: text) else {
            throw Error.embeddingError
        }

        // Convert [Double] to Blob
        // Convert [Double] to Data with little-endian representation using map
        let vectorData = embedding.map(\.bitPattern).withUnsafeBufferPointer({ Data(buffer: $0) })
        let vectorBlob = Blob(bytes: [UInt8](vectorData))

        // Insert text and vector into SQLite and get the key
        let insert = textsTable.insert(textColumn <- text, vectorColumn <- vectorBlob)
        let key = UInt64(try textDB.run(insert))

        // Insert embedding into USearch
        guard !vectorDB.contains(key: key) else {
            return key
        }

        vectorDB.reserve(UInt32(vectorDB.count + 1))
        vectorDB.add(key: key, vector: embedding)
        vectorDB.save(path: vectorDBPath)

        return key
    }
}
