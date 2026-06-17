//
//  PersistenceController.swift
//  Zenly
//
//  Core Data stack. Uses NSPersistentCloudKitContainer with a CloudKit-shaped
//  schema, but leaves `cloudKitContainerOptions` unset — so the store is local
//  for now (no iCloud capability needed). Phase 4 enables sync by setting the
//  container options; no migration required.
//
//  The store lives in the App Group so extensions can read it if needed.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Zenly")

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.url = AppGroup.containerURL.appendingPathComponent("Zenly.sqlite")
        }

        // CloudKit-ready but local: no cloudKitContainerOptions => no sync yet.
        description.cloudKitContainerOptions = nil
        // Lightweight migration for additive model changes (e.g. blockAllApps).
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        // Keep history so a future CloudKit mirror (Phase 4) can replay changes.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // Loud, but non-fatal: surface during on-device testing rather than crash.
                print("[Zenly] Core Data failed to load store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Save the view context if it has pending changes.
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[Zenly] Core Data save failed: \(error)")
        }
    }
}
