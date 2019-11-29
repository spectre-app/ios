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
    public func promised<V>(main: Bool = false, task: @escaping (NSManagedObjectContext) throws -> Promise<V>) -> Promise<V?> {
        self.loadStore().promised {
            let promise = Promise<V?>()

            switch $0 {
                case .success(let storeLoaded):
                    guard storeLoaded
                    else {
                        promise.finish( .success( nil ) )
                        break
                    }

                    let context = main ? self.mainManagedObjectContext: self.privateManagedObjectContext
                    context.perform {
                        do {
                            try task( context ).then {
                                switch $0 {
                                    case .success(let value):
                                        promise.finish( .success( value ) )

                                    case .failure(let error):
                                        promise.finish( .failure( error ) )
                                }
                            }
                        }
                        catch { promise.finish( .failure( error ) ) }
                    }

                case .failure(let error):
                    promise.finish( .failure( error ) )
            }

            return promise
        }
    }

    @discardableResult
    public func promise<V>(main: Bool = false, task: @escaping (NSManagedObjectContext) throws -> V) -> Promise<V?> {
        self.promised( main: main ) { Promise( .success( try task( $0 ) ) ) }
    }

    private func loadStore() -> Promise<Bool> {
        self.storeQueue.promise {
            // Do nothing if already fully set up, otherwise (re-)load the store.
            guard self.storeCoordinator == nil
            else { return true }

            // Unregister any existing observers and contexts.
            self.mainManagedObjectContext.performAndWait {
                self.mainManagedObjectContext.reset()
            }
            self.privateManagedObjectContext.performAndWait {
                self.privateManagedObjectContext.reset()
            }

            guard let identifier = Bundle.main.bundleIdentifier
            else { throw MPError.internal( details: "Missing application identifier" ) }

            guard let storeURL = try? FileManager.default.url( for: .applicationSupportDirectory, in: .userDomainMask,
                                                               appropriateFor: nil, create: false )
                                                         .appendingPathComponent( identifier, isDirectory: true )
                                                         .appendingPathComponent( "MasterPassword", isDirectory: false )
                                                         .appendingPathExtension( "sqlite" )
            else { throw MPError.internal( details: "Couldn't access support directory" ) }

            if !FileManager.default.fileExists( atPath: storeURL.path ) {
                return false
            }

            let storeOptions: [AnyHashable: Any] = [
                NSInferMappingModelAutomaticallyOption: true,
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSPersistentStoreFileProtectionKey: FileProtectionType.complete,
            ]

            // Load the supported data models.
            guard let storeModel = NSManagedObjectModel.mergedModel( from: nil )
            else { throw MPError.internal( details: "Missing data model" ) }

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
    }
}
