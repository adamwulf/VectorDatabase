# VectorDatabase

`VectorDatabase` is a Swift library for embedding and storing text data using SQLite and USearch. It provides functionality to insert, lookup, and search text embeddings.

## Installation

To use `VectorDatabase` in your project, add the following dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/adamwulf/VectorDatabase", .branch("main"))
```

Then, run `swift package update` to fetch the package.

## Usage

### Importing the Library

To use `VectorDatabase`, import it at the top of your Swift file:

```swift
import VectorDatabase
```

### Initializing the Database

Create an instance of `VectorDatabase` by specifying the path where the database files will be stored:

```swift
do {
    let vectorDB = try VectorDatabase(at: "/path/to/database")
} catch {
    print("Failed to initialize VectorDatabase: \(error)")
}
```

### Inserting Text

Insert text into the database and get a unique key for the text:

```swift
do {
    let key = try await vectorDB.insert(text: "example text")
    print("Inserted text with key: \(key)")
} catch {
    print("Failed to insert text: \(error)")
}
```

### Looking Up Text

Lookup text by its content or by its unique key:

```swift
do {
    let result = try vectorDB.lookup(text: "example text")
    print("Found text: \(result.text), embedding: \(result.embedding)")
} catch {
    print("Text not found: \(error)")
}

do {
    let result = try vectorDB.lookup(key: someKey)
    print("Found text: \(result.text), embedding: \(result.embedding)")
} catch {
    print("Text not found: \(error)")
}
```

### Searching for Similar Texts

Search for texts similar to a given text or embedding:

```swift
do {
    let results = try vectorDB.search(text: "example text", count: 10)
    for result in results {
        print("Found key: \(result.key), distance: \(result.distance)")
    }
} catch {
    print("Search failed: \(error)")
}

do {
    let embedding: [Double] = // some embedding
    let results = try vectorDB.search(embedding: embedding, count: 10)
    for result in results {
        print("Found key: \(result.key), distance: \(result.distance)")
    }
} catch {
    print("Search failed: \(error)")
}
```

## Example Command Line Tool

The package also includes a command line tool `vecdb` for embedding and storing input text into a database. You can use it as follows:

```sh
$ swift run vecdb --help
$ swift run vecdb example /path/to/database
```

This will prime the database with some example texts and perform a search.

## License

This project is licensed under the MIT License. See the [LICENSE.md](LICENSE.md) file for details.
