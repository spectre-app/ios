//
// Created by Maarten Billemont on 2019-07-02.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPCoreData {
    public static var shared = MPCoreData()

    private var storeCoordinator: NSPersistentStoreCoordinator?
    private let storeQueue                  = DispatchQueue( label: "coredata", qos: .utility )
    private let mainManagedObjectContext    = NSManagedObjectContext( concurrencyType: .mainQueueConcurrencyType )
    private let privateManagedObjectContext = NSManagedObjectContext( concurrencyType: .privateQueueConcurrencyType )

    @discardableResult
    public func perform(main: Bool = false, async: Bool = true, task: @escaping (NSManagedObjectContext) -> Void) -> Bool {
        guard self.loadStore()
        else {
            return false
        }

        if !async {
            return self.await {
                task( $0 )
                return true
            }
        }
        else {
            if main {
                self.mainManagedObjectContext.perform { task( self.mainManagedObjectContext ) }
            }
            else {
                self.privateManagedObjectContext.perform { task( self.privateManagedObjectContext ) }
            }
            return true
        }
    }

    @discardableResult
    public func await(main: Bool = false, task: @escaping (NSManagedObjectContext) -> Bool) -> Bool {
        guard self.loadStore()
        else {
            return false
        }

        var success = false
        if main {
            self.mainManagedObjectContext.performAndWait { success = task( self.mainManagedObjectContext ) }
        }
        else {
            self.privateManagedObjectContext.performAndWait { success = task( self.privateManagedObjectContext ) }
        }

        return success
    }

    private func loadStore() -> Bool {
        guard self.storeCoordinator == nil
        else {
            return true
        }

        return self.storeQueue.await {
            // Do nothing if already fully set up, otherwise (re-)load the store.
            guard self.storeCoordinator == nil
            else {
                return true
            }

            // Unregister any existing observers and contexts.
            self.mainManagedObjectContext.performAndWait {
                self.mainManagedObjectContext.reset()
            }
            self.privateManagedObjectContext.performAndWait {
                self.privateManagedObjectContext.reset()
            }

            guard let identifier = Bundle.main.bundleIdentifier
            else {
                mperror( title: "Couldn't load legacy data store", context: "Missing application identifier" )
                return false
            }
            guard let localStoreURL = try? FileManager.default.url( for: .applicationSupportDirectory, in: .userDomainMask,
                                                                    appropriateFor: nil, create: false )
                                                              .appendingPathComponent( identifier, isDirectory: true )
                                                              .appendingPathComponent( "MasterPassword", isDirectory: false )
                                                              .appendingPathExtension( "sqlite" )
            else {
                mperror( title: "Couldn't load legacy data store", context: "Couldn't access support directory" )
                return false
            }
            if !FileManager.default.fileExists( atPath: localStoreURL.path ) {
                return false
            }

            do {
                // Open the store and find the model.
                guard let model = NSManagedObjectModel.mergedModel(
                        from: nil, forStoreMetadata: try NSPersistentStoreCoordinator.metadataForPersistentStore( ofType: NSSQLiteStoreType, at: localStoreURL, options: [
                    NSReadOnlyPersistentStoreOption: true,
                    NSInferMappingModelAutomaticallyOption: true,
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSPersistentStoreFileProtectionKey: FileProtectionType.complete,
                ] ) )
                else {
                    mperror( title: "Couldn't load legacy data store", context: "Missing data model" )
                    return false
                }

                // Create a new store coordinator.
                self.storeCoordinator = NSPersistentStoreCoordinator( managedObjectModel: model )
                try self.storeCoordinator?.addPersistentStore(
                        ofType: NSSQLiteStoreType, configurationName: nil, at: localStoreURL, options: [
                    NSReadOnlyPersistentStoreOption: true,
                    NSInferMappingModelAutomaticallyOption: true,
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSPersistentStoreFileProtectionKey: FileProtectionType.complete,
                ] )

                // Install managed object contexts and observers.
                self.privateManagedObjectContext.performAndWait {
                    self.privateManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                    self.privateManagedObjectContext.persistentStoreCoordinator = self.storeCoordinator
                }
                self.mainManagedObjectContext.performAndWait {
                    self.mainManagedObjectContext.parent = self.privateManagedObjectContext
                    if #available( iOS 10.0, * ) {
                        self.mainManagedObjectContext.automaticallyMergesChangesFromParent = true
                    }
                }

                return true
            }
            catch {
                mperror( title: "Couldn't load legacy data store", error: error )
                return false
            }
        }
    }
}
