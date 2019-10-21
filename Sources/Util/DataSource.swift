//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

open class DataSource<E: Hashable> {
    private let tableView:      UITableView?
    private let collectionView: UICollectionView?
    private var sectionsOfElements = [ [ E? ] ]()

    public init(tableView: UITableView? = nil, collectionView: UICollectionView? = nil, sectionsOfElements: [[E]]? = nil) {
        self.tableView = tableView
        self.collectionView = collectionView
        self.sectionsOfElements = sectionsOfElements ?? self.sectionsOfElements
    }

    // MARK: --- Interface ---

    public var numberOfSections: Int {
        self.sectionsOfElements.count
    }

    public func numberOfItems(in section: Int) -> Int {
        section < self.sectionsOfElements.count ? self.sectionsOfElements[section].count: 0
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
                section < self.sectionsOfElements.count &&
                item < self.sectionsOfElements[section].count ?
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
                     reload: Bool = false, reloadPaths: [IndexPath]? = nil, reloadElements: [E?]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil) {
        if updatedSectionsOfElements == self.sectionsOfElements {
            self.perform( animated: animated, completion: completion ) {
                var reloadPaths = reloadPaths ?? []
                for section in self.sectionsOfElements.indices {
                    let elements = self.sectionsOfElements[section]
                    for item in elements.indices {
                        if reload || reloadElements?.contains( where: { $0 == elements[item] } ) ?? false {
                            reloadPaths.append( IndexPath( item: item, section: section ) )
                        }
                    }
                }
                if reloadPaths.count > 0 {
                    //trc( "reload items \(reloadPaths)" )
                    self.collectionView?.reloadItems( at: reloadPaths )
                    self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
                }
            }

            return
        }

        self.perform( animated: animated, completion: completion ) {
            // Figure out how the section items have changed.
            var oldElements = Set<E?>()
            var deletePaths = [ IndexPath ]()
            var movedPaths  = [ IndexPath: IndexPath ]()
            var reloadPaths = reloadPaths ?? []

            for section in self.sectionsOfElements.indices {
                let elements = self.sectionsOfElements[section]
                for item in elements.indices {
                    let element = elements[item]
                    oldElements.insert( element )

                    let fromIndexPath = IndexPath( item: item, section: section )
                    if let toIndexPath = self.indexPath( for: element, in: updatedSectionsOfElements ) {
                        if fromIndexPath != toIndexPath {
                            movedPaths[fromIndexPath] = toIndexPath
                        }
                        else if reload || reloadElements?.contains( where: { $0 == element } ) ?? false {
                            reloadPaths.append( toIndexPath )
                        }
                    }
                    else if section < updatedSectionsOfElements.count {
                        deletePaths.append( fromIndexPath )
                    }
                }
            }

            // Figure out what sections were added and removed.
            var insertSet = IndexSet(), deleteSet = IndexSet()
            for section in (0..<max( self.sectionsOfElements.count, updatedSectionsOfElements.count )).reversed() {
                if section >= updatedSectionsOfElements.count {
                    //trc( "delete section \(section)" )
                    self.sectionsOfElements.remove( at: section )
                    deleteSet.insert( section )
                }
                else if section >= self.sectionsOfElements.count {
                    //trc( "insert section \(section)" )
                    self.sectionsOfElements.append( updatedSectionsOfElements[section] )
                    insertSet.insert( section )
                }
                else {
                    self.sectionsOfElements[section] = updatedSectionsOfElements[section]
                }
            }
            self.collectionView?.insertSections( insertSet )
            self.collectionView?.deleteSections( deleteSet )
            self.tableView?.insertSections( insertSet, with: .automatic )
            self.tableView?.deleteSections( deleteSet, with: .automatic )

            var insertPaths = [ IndexPath ]()
            for section in 0..<updatedSectionsOfElements.count {
                let newSectionItems = updatedSectionsOfElements[section]
                for index in 0..<newSectionItems.count {
                    if oldElements.remove( newSectionItems[index] ) == nil {
                        insertPaths.append( IndexPath( item: index, section: section ) )
                    }
                }
            }

            // Reload existing items.
            //for path in reloadPaths { trc( "reload item \(path)" ) }
            self.collectionView?.reloadItems( at: reloadPaths )
            self.tableView?.reloadRows( at: reloadPaths, with: .automatic )

            // Remove deleted rows.
            //for path in deletePaths { trc( "delete item \(path)" )}
            self.collectionView?.deleteItems( at: deletePaths )
            self.tableView?.deleteRows( at: deletePaths, with: .automatic )

            // Add inserted rows.
            //for path in insertPaths { trc( "insert item \(path)" ) }
            self.collectionView?.insertItems( at: insertPaths )
            self.tableView?.insertRows( at: insertPaths, with: .automatic )

            // Then shuffle around moved rows.
            movedPaths.forEach { fromIndexPath, toIndexPath in
                //trc( "move item \(fromIndexPath) -> \(toIndexPath)" )
                self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
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

    private func perform(animated: Bool = true, completion: ((Bool) -> Void)?, updates: @escaping () -> Void) {
        DispatchQueue.main.perform {
            if self.tableView == nil && self.collectionView == nil {
                preconditionFailure( "Data source not associated with a data view." )
            }

            let task = {
                if #available( iOS 11.0, * ) {
                    self.tableView?.performBatchUpdates( updates, completion: completion )
                }
                else {
                    self.tableView?.beginUpdates()
                    updates()
                    self.tableView?.endUpdates()
                    completion?( true )
                }

                self.collectionView?.performBatchUpdates( updates, completion: completion )
            }

            if animated {
                task()
            }
            else {
                UIView.performWithoutAnimation( task )
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
