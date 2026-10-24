import Dependencies
import Foundation
import OSLog
import SQLiteData

/// A timeline's cached state: what's needed to show it again instantly before the network answers.
@Table("timelines")
struct TimelineRecord: Identifiable {
    /// `FeedSource.cacheKey`.
    let id: String
    /// The item at the top of the screen when the reader last stopped scrolling: where to put them back.
    @Column("anchorItemID")
    var topItemID: String?
    var bottomCursor: String?
    var refreshedAt: Date
}

/// One row of a cached timeline. The item is stored as encoded JSON and decoded per row, so a model change that
/// makes old rows undecodable turns into a cache miss instead of an error.
@Table("timelineEntries")
struct TimelineEntryRecord: Identifiable {
    /// `"\(timelineID)|\(itemID)"`: unique per timeline without a compound key.
    let id: String
    var timelineID: String
    var position: Int
    var payload: Data
}

/// Profiles seen recently, so a pushed profile can draw its header before the network answers.
@Table("users")
struct UserRecord: Identifiable {
    /// The lowercased screen name, which is how profiles are opened.
    let id: String
    var payload: Data
    var fetchedAt: Date
}

extension DependencyValues {
    /// Opens the app's database and runs its migrations. Everything in it is a cache of Twitter's data, safe to lose.
    package mutating func bootstrapDatabase() throws {
        var configuration = Configuration()
        configuration.prepareDatabase { [context] db in
            #if DEBUG
                db.trace(options: .profile) {
                    guard !$0.expandedDescription.hasPrefix("--") else { return }
                    switch context {
                    case .live:
                        logger.debug("\($0.expandedDescription)")
                    case .preview:
                        print("\($0.expandedDescription)")
                    case .test:
                        break
                    }
                }
            #endif
        }
        let database = try SQLiteData.defaultDatabase(configuration: configuration)
        var migrator = DatabaseMigrator()
        #if DEBUG
            migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("Create 'timelines', 'timelineEntries' and 'users' tables") { db in
            try #sql(
                """
                CREATE TABLE "timelines" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "bottomCursor" TEXT,
                  "refreshedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "timelineEntries" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "timelineID" TEXT NOT NULL REFERENCES "timelines"("id") ON DELETE CASCADE,
                  "position" INTEGER NOT NULL,
                  "payload" BLOB NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE INDEX "index_timelineEntries_on_timelineID_position"
                ON "timelineEntries"("timelineID", "position")
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "users" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "payload" BLOB NOT NULL,
                  "fetchedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
        }
        migrator.registerMigration("Add 'anchorItemID' to 'timelines'") { db in
            try #sql(
                """
                ALTER TABLE "timelines" ADD COLUMN "anchorItemID" TEXT
                """
            )
            .execute(db)
        }
        try migrator.migrate(database)
        defaultDatabase = database
    }
}

private let logger = Logger(subsystem: "gold.samhenri.Twitter", category: "Database")
