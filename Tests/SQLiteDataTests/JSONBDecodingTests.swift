import Foundation
import SQLiteData
import Testing

@Suite struct JSONBDecodingTests {
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  @DatabaseFunction(as: ((AttributedString.JSONBRepresentation) -> String).self)
  private func string(from attributedString: AttributedString) -> String {
    String(attributedString.characters[...])
  }
  
  @available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
  @Test func triggerWithJSONBArgument() throws {
    var configuration = Configuration()
    configuration.prepareDatabase { db in
      db.add(function: $string)
    }
    let database = try DatabaseQueue(configuration: configuration)
    
    try database.write { db in
      try #sql(
        """
        CREATE TABLE "items" (
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "text" BLOB NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      
      try #sql(
        """
        CREATE VIRTUAL TABLE "itemTexts" USING fts5(
          "itemID" UNINDEXED,
          "text",
          tokenize='trigram'
        )
        """
      ).execute(db)
    }
    
    try database.write { db in
      try Item.createTemporaryTrigger(
        after: .insert { new in
          ItemText.insert {
            ItemText.Columns(
              itemID: new.id,
              text: $string(from: new.text)
            )
          }
        }
      ).execute(db)
    }
    
    try database.write { db in
      try Item.insert {
        Item.Draft(text: AttributedString("blob"))
      }.execute(db)
    }
  }
}

@available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
@Table
private struct Item: Identifiable {
  let id: Int
  @Column(as: AttributedString.JSONBRepresentation.self)
  var text: AttributedString
}

@available(iOS 26, macOS 26, tvOS 26, watchOS 26, *)
@Table
private struct ItemText: FTS5 {
  @Column(primaryKey: true) let itemID: Item.ID
  let text: String
}
