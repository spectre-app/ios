//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

open class DataSource<E: Hashable> {
    private let tableView:      UITableView?
    private let collectionView: UICollectionView?
    private var elementsConsumed   = false
    private var sectionsOfElements = [ [ E? ] ]()

    public var isEmpty: Bool {
        self.sectionsOfElements.reduce( true ) { $0 && $1.isEmpty }
    }

    public init(tableView: UITableView? = nil, collectionView: UICollectionView? = nil, sectionsOfElements: [[E]]? = nil) {
        self.tableView = tableView
        self.collectionView = collectionView
        self.sectionsOfElements = sectionsOfElements ?? self.sectionsOfElements
    }

    // MARK: --- Interface ---

    public var numberOfSections: Int {
        self.elementsConsumed = true
        return self.sectionsOfElements.count
    }

    public func numberOfItems(in section: Int) -> Int {
        self.elementsConsumed = true
        return section < self.sectionsOfElements.count ? self.sectionsOfElements[section].count: 0
    }

    open func indexPath(for item: E?) -> IndexPath? {
        self.indexPath( for: item, in: self.sectionsOfElements )
    }

    open func indexPath(where predicate: (E?) -> Bool) -> IndexPath? {
        self.indexPath( where: predicate, in: self.sectionsOfElements )
    }

    open func element(at indexPath: IndexPath?) -> E? {
        guard let indexPath = indexPath
        else { return nil }

        return element( item: indexPath.item, section: indexPath.section )
    }

    open func element(item: Int?, section: Int = 0) -> E? {
        guard let item = item
        else { return nil }

        return section >= 0 && item >= 0 &&
                section < self.sectionsOfElements.count && item < self.sectionsOfElements[section].count ?
                self.sectionsOfElements[section][item]: nil
    }

    open func elements() -> AnySequence<(indexPath: IndexPath, element: E?)> {
        // TODO: inline these types
        let s: LazySequence<FlattenSequence<LazyMapSequence<EnumeratedSequence<[[E?]]>, LazyMapSequence<EnumeratedSequence<[E?]>, (indexPath: IndexPath, element: E?)>>>>
                = self.sectionsOfElements.enumerated().lazy.flatMap {
            let (section, sectionElements) = $0

            return sectionElements.enumerated().lazy.map {
                let (item, element) = $0

                return (indexPath: IndexPath( item: item, section: section ), element: element)
            }
        }
        return AnySequence<(indexPath: IndexPath, element: E?)>( s )
    }

    open func update(_ updatedSectionsOfElements: [[E?]],
                     reloadItems: Bool = false, reloadPaths: [IndexPath]? = nil, reloadElements: [E?]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil) {
        trc( "updating dataSource:\n%@\n<=\n%@", self.sectionsOfElements, updatedSectionsOfElements )

        if !self.elementsConsumed {
            self.sectionsOfElements = updatedSectionsOfElements
            completion?( true )
            return
        }

        self.perform( animated: animated, completion: completion ) {
            let updateIncrementally = !animated
            var reloadPaths         = reloadPaths ?? []

            if updatedSectionsOfElements == self.sectionsOfElements {
                for (section, elements) in self.sectionsOfElements.enumerated() {
                    for (item, element) in elements.enumerated() {
                        if reloadItems || reloadElements?.contains( where: { $0 == element } ) ?? false {
                            let indexPath = IndexPath( item: item, section: section )
                            trc( "reload item %@", indexPath )
                            reloadPaths.append( indexPath )
                        }
                    }
                }
            }
            else {
                // Update the internal data sections and determine which sections changed.
                for section in (0..<max( self.sectionsOfElements.count, updatedSectionsOfElements.count )).reversed() {
                    if section >= updatedSectionsOfElements.count {
                        trc( "delete section %d", section )
                        if updateIncrementally {
                            self.sectionsOfElements.remove( at: section )
                        }
                        self.collectionView?.deleteSections( IndexSet( integer: section ) )
                        self.tableView?.deleteSections( IndexSet( integer: section ), with: .automatic )
                    }
                }
                for section in 0..<max( self.sectionsOfElements.count, updatedSectionsOfElements.count ) {
                    if section >= self.sectionsOfElements.count {
                        trc( "insert section %d", section )
                        if updateIncrementally {
                            self.sectionsOfElements.append( [ E? ]() )
                        }
                        self.collectionView?.insertSections( IndexSet( integer: section ) )
                        self.tableView?.insertSections( IndexSet( integer: section ), with: .automatic )
                    }
                }

                // Figure out how the section items have changed.
                for (section, elements) in updatedSectionsOfElements.enumerated() {
                    for (item, element) in elements.enumerated() {
                        let toIndexPath = IndexPath( item: item, section: section )
                        if let fromIndexPath = self.indexPath( for: element, in: self.sectionsOfElements ) {
                            if toIndexPath != fromIndexPath {
                                trc( "move item %@ -> %@", fromIndexPath, toIndexPath )
                                if updateIncrementally {
                                    self.sectionsOfElements[fromIndexPath.section].remove( at: fromIndexPath.item )
                                    self.sectionsOfElements[toIndexPath.section].insert( element, at: toIndexPath.item )
                                }
                                self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                                self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                            }
                            else if reloadItems || reloadElements?.contains( where: { $0 == element } ) ?? false {
                                trc( "reload item %@", fromIndexPath )
                                if updateIncrementally {
                                    self.sectionsOfElements[fromIndexPath.section][fromIndexPath.item] = element
                                }
                                reloadPaths.append( fromIndexPath )
                            }
                        }
                        else {
                            trc( "insert item %@", toIndexPath )
                            if updateIncrementally {
                                self.sectionsOfElements[toIndexPath.section].insert( element, at: toIndexPath.item )
                            }
                            self.collectionView?.insertItems( at: [ toIndexPath ] )
                            self.tableView?.insertRows( at: [ toIndexPath ], with: .automatic )
                        }
                    }
                }

                // Add inserted rows.
                for (section, elements) in self.sectionsOfElements.enumerated() {
                    for (item, element) in elements.enumerated().reversed() {
                        let fromIndexPath = IndexPath( item: item, section: section )
                        if self.indexPath( for: element, in: updatedSectionsOfElements ) == nil {
                            trc( "delete item %@", fromIndexPath )
                            if updateIncrementally {
                                self.sectionsOfElements[section].remove( at: item )
                            }
                            self.collectionView?.deleteItems( at: [ fromIndexPath ] )
                            self.tableView?.deleteRows( at: [ fromIndexPath ], with: .automatic )
                        }
                    }
                }
            }

            self.sectionsOfElements = updatedSectionsOfElements

            if reloadPaths.count > 0 {
                trc( "reload items %@", reloadPaths )
                self.collectionView?.reloadItems( at: reloadPaths )
                self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
            }
        }
    }

    @discardableResult
    open func remove(_ item: E, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        if let indexPath = self.indexPath( for: item ) {
            self.perform( animated: animated, completion: completion ) {
                self.sectionsOfElements[indexPath.section].remove( at: indexPath.item )
                self.collectionView?.deleteItems( at: [ indexPath ] )
                self.tableView?.deleteRows( at: [ indexPath ], with: .automatic )
            }
            return true
        }

        return false
    }

    // MARK: --- Private ---

    private func perform(animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)?, updates: @escaping () -> Void) {
        DispatchQueue.main.perform {
            if self.tableView == nil && self.collectionView == nil {
                preconditionFailure( "Data source not associated with a data view." )
            }

            if !animated {
                updates()
                completion?( true )
            }
            else {
                self.tableView?.performBatchUpdates( updates, completion: completion )
                self.collectionView?.performBatchUpdates( updates, completion: completion )
            }
        }
    }

    private func indexPath<E: Hashable>(for item: E?, in sections: [[E?]]?) -> IndexPath? {
        self.indexPath( where: { $0 == item }, in: sections )
    }

    private func indexPath<E: Hashable>(where predicate: (E?) -> Bool, in sections: [[E?]]?) -> IndexPath? {
        var section = 0
        if let sections = sections {
            for sectionItems in sections {
                if let index = sectionItems.firstIndex( where: predicate ) {
                    return IndexPath( item: index, section: section )
                }

                section += 1
            }
        }

        return nil
    }
}
