import Foundation
import SQLite

// Avoid Expression name collision
private typealias Expression = SQLite.Expression

enum MigrationManager {
    /// Ensures meta table exists and schema_version is set.
    /// For now, bootstrap to version 1 if missing.
    static func migrate(db: SQLite.Connection) throws {
        let meta = Table("meta")
        let k = Expression<String>("key")
        let v = Expression<String>("value")

        try db.run(meta.create(ifNotExists: true) { t in
            t.column(k, primaryKey: true)
            t.column(v)
        })

        let versionRow = try db.pluck(meta.filter(k == "schema_version"))
        if versionRow == nil {
            try db.run(meta.insert(or: .replace, k <- "schema_version", v <- "1"))
        }
        // Future migrations: read version and apply incremental SQL changes, then update value.
    }
}
