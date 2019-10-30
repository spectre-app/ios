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
    public func promised<V>(main: Bool = false, task: @escaping (NSManagedObjectContext) throws -> Promise<V>) -> Promise<V>? {
        guard self.loadStore()
        else { return nil }

        let promise = Promise<V>()
        let context = main ? self.mainManagedObjectContext: self.privateManagedObjectContext
        context.perform {
            do { try task( context ).then { promise.finish( $0 ) } }
            catch { promise.finish( .failure( error ) ) }
        }

        return promise
    }

    @discardableResult
    public func promise<V>(main: Bool = false, task: @escaping (NSManagedObjectContext) throws -> V) -> Promise<V>? {
        self.promised( main: main ) { Promise( .success( try task( $0 ) ) ) }
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
                mperror( title: "Couldn't load legacy data", message: "Missing application identifier" )
                return false
            }
            guard let storeURL = try? FileManager.default.url( for: .applicationSupportDirectory, in: .userDomainMask,
                                                               appropriateFor: nil, create: false )
                                                         .appendingPathComponent( identifier, isDirectory: true )
                                                         .appendingPathComponent( "MasterPassword", isDirectory: false )
                                                         .appendingPathExtension( "sqlite" )
            else {
                mperror( title: "Couldn't load legacy data", message: "Couldn't access support directory" )
                return false
            }
            if !FileManager.default.fileExists( atPath: storeURL.path ) {
                return false
            }

            do {
                let storeOptions: [AnyHashable: Any] = [
                    NSReadOnlyPersistentStoreOption: true,
                    NSInferMappingModelAutomaticallyOption: true,
                    NSMigratePersistentStoresAutomaticallyOption: false,
                    NSPersistentStoreFileProtectionKey: FileProtectionType.complete,
                ]

                // Open the store and find the model.
                let storeMetadata                    = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                        ofType: NSSQLiteStoreType, at: storeURL, options: storeOptions )
                guard let storeModel = NSManagedObjectModel.mergedModel( from: nil, forStoreMetadata: storeMetadata )
                else {
                    mperror( title: "Couldn't load legacy data", message: "Unsupported data model", details: storeMetadata )
                    return false
                }

                // Create a new store coordinator.
                self.storeCoordinator = NSPersistentStoreCoordinator( managedObjectModel: storeModel )
                try self.storeCoordinator?.addPersistentStore(
                        ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: storeOptions )

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
                mperror( title: "Couldn't load legacy data", error: error )
                return false
            }
        }
    }
}
