//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

open class DataSource<E: Hashable> {
    private let collectionView: UICollectionView?
    private let tableView:      UITableView?
    private var dataSource = [ [ E? ] ]()

    public init(collectionView: UICollectionView? = nil, tableView: UITableView? = nil, dataSource: [[E]]? = nil) {
        self.collectionView = collectionView
        self.tableView = tableView
        self.dataSource = dataSource ?? self.dataSource
    }

    open func update(_ newSections: [[E?]],
                     reload: Bool = false, reloadPaths: [IndexPath]? = nil, reloadElements: [E?]? = nil,
                     completion: ((Bool) -> Void)? = nil) {

        if newSections == self.dataSource {
            self.collectionView?.performBatchUpdates(
                    {
                        var reloadPaths = reloadPaths ?? []
                        for section in self.dataSource.indices {
                            let elements = self.dataSource[section]
                            for item in elements.indices {
                                if reload || reloadElements?.contains( where: { $0 == elements[item] } ) ?? false {
                                    reloadPaths.append( IndexPath( item: item, section: section ) )
                                }
                            }
                        }
                        if reloadPaths.count > 0 {
                            trc( "reload items \(reloadPaths)" )
                            self.collectionView?.reloadItems( at: reloadPaths )
                            self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
                        }
                    }, completion: completion )
            return
        }

        do {
            self.collectionView?.performBatchUpdates(
                    {
                        // Figure out how the section items have changed.
                        var oldElements = Set<E?>()
                        var deletePaths = [ IndexPath ]()
                        var movedPaths  = [ IndexPath: IndexPath ]()
                        var reloadPaths = reloadPaths ?? []

                        for section in self.dataSource.indices {
                            let elements = self.dataSource[section]
                            for item in elements.indices {
                                let element = elements[item]
                                oldElements.insert( element )

                                let fromIndexPath = IndexPath( item: item, section: section )
                                if let toIndexPath = indexPath( for: element, in: newSections ) {
                                    if fromIndexPath != toIndexPath {
                                        movedPaths[fromIndexPath] = toIndexPath
                                    }
                                    else if reload || reloadElements?.contains( where: { $0 == element } ) ?? false {
                                        reloadPaths.append( toIndexPath )
                                    }
                                }
                                else if section < newSections.count {
                                    deletePaths.append( fromIndexPath )
                                }
                            }
                        }

                        // Figure out what sections were added and removed.
                        var insertSet = IndexSet(), deleteSet = IndexSet()
                        for section in 0..<max( self.dataSource.count, newSections.count ) {
                            if section >= self.dataSource.count {
                                trc( "insert section \(section)" )
                                self.dataSource.append( newSections[section] )
                                insertSet.insert( section )
                            }
                            else if section >= newSections.count {
                                trc( "delete section \(section)" )
                                self.dataSource.remove( at: self.dataSource.count - 1 )
                                deleteSet.insert( section )
                            }
                            else {
                                self.dataSource[section] = newSections[section]
                            }
                        }
                        self.collectionView?.insertSections( insertSet )
                        self.collectionView?.deleteSections( deleteSet )
                        self.tableView?.insertSections( insertSet, with: .automatic )
                        self.tableView?.deleteSections( deleteSet, with: .automatic )

                        var insertPaths = [ IndexPath ]()
                        for section in 0..<newSections.count {
                            let newSectionItems = newSections[section]
                            for index in 0..<newSectionItems.count {
                                if oldElements.remove( newSectionItems[index] ) == nil {
                                    insertPaths.append( IndexPath( item: index, section: section ) )
                                }
                            }
                        }

                        // Reload existing items.
                        for path in reloadPaths {
                            trc( "reload item \(path)" )
                        }
                        self.collectionView?.reloadItems( at: reloadPaths )
                        self.tableView?.reloadRows( at: reloadPaths, with: .automatic )

                        // Remove deleted rows.
                        for path in deletePaths {
                            trc( "delete item \(path)" )
                        }
                        self.collectionView?.deleteItems( at: deletePaths )
                        self.tableView?.deleteRows( at: deletePaths, with: .automatic )

                        // Add inserted rows.
                        for path in insertPaths {
                            trc( "insert item \(path)" )
                        }
                        self.collectionView?.insertItems( at: insertPaths )
                        self.tableView?.insertRows( at: insertPaths, with: .automatic )

                        // Then shuffle around moved rows.
                        movedPaths.forEach { fromIndexPath, toIndexPath in
                            trc( "move item \(fromIndexPath) -> \(toIndexPath)" )
                            self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                            self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                        }
                    }, completion: completion )
        }
        catch {
            wrn( "Exception while reloading sections for table.  Falling back to a full reload.\n\(error)" )
            do {
                self.collectionView?.reloadData()
                self.tableView?.reloadData()
            }
            catch {
                err( "Exception during fallback reload.\n\(error)" )
            }
        }
    }

    @discardableResult
    open func remove(_ item: E, completion: ((Bool) -> Void)? = nil) -> Bool {
        if let indexPath = self.indexPath( for: item ) {
            self.collectionView?.performBatchUpdates(
                    {
                        self.dataSource[indexPath.section].remove( at: indexPath.item )
                        self.collectionView?.deleteItems( at: [ indexPath ] )
                        self.tableView?.deleteRows( at: [ indexPath ], with: .automatic )
                    }, completion: completion )
            return true
        }

        return false
    }

    open func element(at indexPath: IndexPath) -> E? {
        return indexPath.section < self.dataSource.count && indexPath.item < self.dataSource[indexPath.section].count ?
                self.dataSource[indexPath.section][indexPath.item] : nil
    }

    public var numberOfSections: Int {
        return self.dataSource.count
    }

    public func numberOfItems(in section: Int) -> Int {
        return section < self.dataSource.count ? self.dataSource[section].count : 0
    }

    open func indexPath(for item: E) -> IndexPath? {
        return indexPath( for: item, in: self.dataSource )
    }

    private func indexPath<E: Hashable>(for item: E, in sections: [[E]]?) -> IndexPath? {

        var section = 0
        if let sections = sections {
            for sectionItems in sections {
                if let index = sectionItems.firstIndex( where: { $0 == item } ) {
                    return IndexPath( item: index, section: section )
                }

                section += 1
            }
        }

        return nil
    }
}
