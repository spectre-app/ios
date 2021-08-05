// =============================================================================
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import UIKit

/**
 A container for data that will be consumed by a UITableView or a UICollectionView.

 You can use this object as your table or collection view's `dataSource`.

 Updating the data in this container will automatically trigger calls in the table or collection view to update their cells to match.

 Moves, inserts and deletes are determined based on the data item's `id` if it is `Identifiable` or its equality otherwise.

 Automatic reloads are triggered for unmoved items that are not equal to their older item.
 This implies the new item's `id` is equal to the old item, but the items themselves are not equal.

 NOTE:
 Due to a bug in performBatchUpdates, moving elements from one section to another while deleting the source section
 is not animated due to it triggering a full reloadData. The work-around is to leave the section empty (or remove it separately).
 http://www.openradar.me/48941363
 */
class DataSource<E: Hashable>: NSObject, UICollectionViewDataSource, UITableViewDataSource {
    private let semaphore = DispatchGroup()
    private let queue     = DispatchQueue( label: "DataSource" )
    private var elements: [[E]]
    private weak var tableView:      UITableView?
    private weak var collectionView: UICollectionView?

    public var isFirstTimeUse = true
    public var isEmpty: Bool {
        self.elements.reduce( true ) { $0 && $1.isEmpty }
    }

    public init(tableView: UITableView, sectionsOfElements: [[E]] = []) {
        self.tableView = tableView
        self.collectionView = nil
        self.elements = sectionsOfElements
    }

    public init(collectionView: UICollectionView, sectionsOfElements: [[E]] = []) {
        self.tableView = nil
        self.collectionView = collectionView
        self.elements = sectionsOfElements
    }

    // MARK: - Interface

    func count(section: Int? = nil) -> Int {
        if let section = section {
            return self.elements[section].count
        }
        else {
            return self.elements.reduce( 0 ) { $0 + $1.count }
        }
    }

    func indexPath(for item: E?) -> IndexPath? {
        item.flatMap { self.indexPath( for: $0, in: self.elements, elementsMatch: { $0 == $1 } ) }
    }

    func indexPath(for item: E?) -> IndexPath? where E: Identifiable {
        item.flatMap { self.indexPath( for: $0, in: self.elements, elementsMatch: { $0.id == $1.id } ) }
    }

    func indexPath(where predicate: (E) -> Bool) -> IndexPath? {
        self.indexPath( where: predicate, in: self.elements )
    }

    func firstElement(section: Int? = nil) -> E? {
        if let section = section {
            return self.elements[section].first
        }
        else {
            return self.elements.reduce( nil ) { $0 ?? $1.first }
        }
    }

    func firstElement(where predicate: (E) -> Bool) -> E? {
        self.elements.flatMap { $0 }.first( where: predicate ).flatMap { $0 }
    }

    func element(at indexPath: IndexPath?) -> E? {
        guard let indexPath = indexPath
        else { return nil }

        return element( item: indexPath.item, section: indexPath.section )
    }

    func element(item: Int?, section: Int = 0) -> E? {
        guard let item = item
        else { return nil }

        return section >= 0 && item >= 0 &&
                section < self.elements.count && item < self.elements[section].count ?
                self.elements[section][item]: nil
    }

    func enumerated() -> AnySequence<(indexPath: IndexPath, element: E)> {
        AnySequence( self.elements.enumerated().lazy.flatMap {
            (enumeratedSection) -> LazyMapSequence<EnumeratedSequence<[E]>, (indexPath: IndexPath, element: E)> in
            let (section, sectionElements) = enumeratedSection

            return sectionElements.enumerated().lazy.map { (enumeratedElement) in
                let (item, element) = enumeratedElement

                return (indexPath: IndexPath( item: item, section: section ), element: element)
            }
        } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    func update(_ toElements: [[E]], selected selectElements: [E]? = nil, selecting selectPaths: [IndexPath]? = nil,
                reload reloadAll: Bool = false, reloaded reloadElements: [E]? = nil, reloading reloadPaths: [IndexPath]? = nil,
                animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil) {
        self.update( toElements, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0 == $1 } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    func update(_ toElements: [[E]], selected selectElements: [E]? = nil, selecting selectPaths: [IndexPath]? = nil,
                reload reloadAll: Bool = false, reloaded reloadElements: [E]? = nil, reloading reloadPaths: [IndexPath]? = nil,
                animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil)
            where E: Identifiable {
        self.update( toElements, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0.id == $1.id } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    private func update(_ toElements: [[E]], selected selectElements: [E]? = nil, selecting selectPaths: [IndexPath]? = nil,
                        reload reloadAll: Bool = false, reloaded reloadElements: [E]? = nil, reloading reloadPaths: [IndexPath]? = nil,
                        animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil,
                        elementsMatch: @escaping (E, E) -> Bool) {
        self.queue.await {
            //dbg( "%@: wait", self.semaphore )
            self.semaphore.wait()
            //dbg( "%@: enter", self.semaphore )
            self.semaphore.enter()
        }

        //dbg( "updating dataSource:\n%@\n<=\n%@", self.elements, toElements )

        if self.isFirstTimeUse || !animated {
            //dbg( "%@: perform", self.semaphore )
            DispatchQueue.main.perform( group: self.semaphore ) {
                self.elements = toElements
                if !self.isFirstTimeUse {
                    self.tableView?.reloadData()
                    self.collectionView?.reloadData()
                }
                DispatchQueue.main.async {
                    self.select( selectElements, paths: selectPaths )
                }
                //dbg( "%@: leave", self.semaphore )
                self.semaphore.leave()
                completion?( true )
                //dbg( "%@: done", self.semaphore )
            }
            return
        }

        // RELOAD ITEMS: Check if element values have changed and mark updated paths for reload.
        var reloadPaths = reloadPaths ?? []
        for (toSection, toElements) in toElements.enumerated() {
            for (toItem, toElement) in toElements.enumerated()
                where reloadAll || (reloadElements?.contains( toElement ) ?? false) || {
                    let fromElement = self.firstElement( where: { elementsMatch( $0, toElement ) } )
                    return fromElement != nil && fromElement != toElement }() {
                // Element reload requested or required due to the new element being different from the old.
                reloadPaths.append( IndexPath( item: toItem, section: toSection ) )
            }
        }

        self.performBatch( reloads: reloadPaths ) {
            // Check if element layout has changed and apply deletes, inserts & moves required to adopt new layout, in that order.
            if !self.elements.elementsEqual( toElements, by: { $0.elementsEqual( $1, by: elementsMatch ) } ) {
                // DELETE SECTIONS: Remove dataSource sections no longer present in the new sections (should be empty of items now).
                for section in (0..<self.elements.count).reversed()
                    where section >= toElements.count {
                    //dbg( "delete section %d", section )
                    self.elements.remove( at: section )
                    self.collectionView?.deleteSections( IndexSet( integer: section ) )
                    self.tableView?.deleteSections( IndexSet( integer: section ), with: .automatic )
                }

                // INSERT SECTIONS: Add empty dataSource sections for newly introduced sections.
                for toSection in 0..<toElements.count
                    where toSection >= self.elements.count {
                    //dbg( "insert section %d", toSection )
                    self.elements.append( [ E ]() )
                    self.collectionView?.insertSections( IndexSet( integer: toSection ) )
                    self.tableView?.insertSections( IndexSet( integer: toSection ), with: .automatic )
                }

                // TODO: reload sections?
                // TODO: move sections?

                // DELETE ITEMS: Delete dataSource elements no longer reflected in the new sections.
                for (fromSection, fromElements) in self.elements.enumerated() {
                    var deletedItems = 0
                    for (fromItem, fromElement) in fromElements.enumerated() {
                        if let toIndexPath = self.indexPath( for: fromElement, in: toElements, elementsMatch: elementsMatch ) {
                            let fromIndexPath = IndexPath( item: fromItem - deletedItems, section: fromSection )
                            if fromIndexPath != toIndexPath {
                                //dbg( "move item %@ -> %@", fromIndexPath, toIndexPath )
                                self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                                self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                            }
                        }
                        else {
                            let fromIndexPath = IndexPath( item: fromItem, section: fromSection )
                            //dbg( "delete item %@", fromIndexPath )
                            self.collectionView?.deleteItems( at: [ fromIndexPath ] )
                            self.tableView?.deleteRows( at: [ fromIndexPath ], with: .automatic )
                            deletedItems += 1
                        }
                    }
                }

                // INSERT ITEMS: Reflect the new sections by moving or reloading existing elements and inserting missing ones.
                for (toSection, toElements) in toElements.enumerated() {
                    for (toItem, toElement) in toElements.enumerated()
                        where self.indexPath( for: toElement, in: self.elements, elementsMatch: elementsMatch ) == nil {
                        // New element missing in old dataSource.
                        let toIndexPath = IndexPath( item: toItem, section: toSection )
                        //dbg( "insert item %@", toIndexPath )
                        self.collectionView?.insertItems( at: [ toIndexPath ] )
                        self.tableView?.insertRows( at: [ toIndexPath ], with: .automatic )
                    }
                }
            }

            self.elements = toElements

            //dbg( "%@: leave", self.semaphore )
            self.semaphore.leave()
        } completion: { success in
            if success {
                self.select( selectElements, paths: selectPaths )
            }
            completion?( success )
        }
    }

    func select(_ elements: [E]? = nil, paths: [IndexPath]? = nil, animated: Bool = true) {
        guard elements != nil || paths != nil
        else { return }

        var selectionPaths = paths ?? []
        selectionPaths.append( contentsOf: elements?.compactMap { self.indexPath( for: $0 ) } ?? [] )

        if self.tableView?.allowsMultipleSelection ?? false || self.collectionView?.allowsMultipleSelection ?? false
                   || selectionPaths.isEmpty {
            self.tableView?.indexPathsForSelectedRows?.filter { !selectionPaths.contains( $0 ) }.forEach {
                //dbg( "deselect item %@", $0 )
                self.tableView?.deselectRow( at: $0, animated: animated )
            }
            self.collectionView?.indexPathsForSelectedItems?.filter { !selectionPaths.contains( $0 ) }.forEach {
                //dbg( "deselect item %@", $0 )
                self.collectionView?.deselectItem( at: $0, animated: animated )
            }
        }
        else if selectionPaths.count > 1 {
            selectionPaths = [ selectionPaths[0] ]
        }

        //dbg( "select items %@", selectionPaths )
        if !((self.tableView ?? self.collectionView)?.bounds.isEmpty ?? true) {
            if self.tableView?.indexPathsForSelectedRows ?? self.collectionView?.indexPathsForSelectedItems == selectionPaths,
               let scrolledPath = selectionPaths.first {
                self.tableView?.scrollToNearestSelectedRow( at: .middle, animated: animated )
                self.collectionView?.scrollToItem( at: scrolledPath, at: .centeredHorizontally, animated: animated )
            }
            else {
                selectionPaths.forEach {
                    self.tableView?.selectRow( at: $0, animated: animated, scrollPosition: .middle )
                    self.collectionView?.selectItem( at: $0, animated: animated, scrollPosition: .centeredHorizontally )
                }
            }
        }
    }

    @discardableResult
    func remove(_ item: E, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        self.remove( at: self.indexPath( for: item ) )
    }

    @discardableResult
    func remove(at indexPath: IndexPath?, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard let indexPath = indexPath,
              indexPath.section < self.elements.count && indexPath.item < self.elements[indexPath.section].count
        else { return false }

        self.performBatch {
            self.elements[indexPath.section].remove( at: indexPath.item )
            self.collectionView?.deleteItems( at: [ indexPath ] )
            self.tableView?.deleteRows( at: [ indexPath ], with: .automatic )
        } completion: { completion?( $0 ) }
        return true
    }

    @discardableResult
    func move(at fromIndexPath: IndexPath, to toIndexPath: IndexPath, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard fromIndexPath.section < self.elements.count && fromIndexPath.item < self.elements[fromIndexPath.section].count,
              toIndexPath.section < self.elements.count && toIndexPath.item < self.elements[toIndexPath.section].count
        else { return false }

        self.performBatch {
            let element = self.elements[fromIndexPath.section].remove( at: fromIndexPath.item )

            var toItem = toIndexPath.item
            if toIndexPath.section == fromIndexPath.section && toIndexPath.item >= fromIndexPath.item {
                toItem -= 1
            }

            self.elements[toIndexPath.section].insert( element, at: toItem )
            self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
            self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
        } completion: { completion?( $0 ) }
        return true
    }

    // MARK: - UICollectionViewDataSource

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        self.isFirstTimeUse = false
        return self.elements.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.isFirstTimeUse = false
        return section < self.elements.count ? self.elements[section].count: 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError( "collectionView(_:cellForItemAt:) has not been implemented" )
    }

    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        false
    }

    public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath,
                               to destinationIndexPath: IndexPath) {
        self.move( at: sourceIndexPath, to: destinationIndexPath )
    }

    // MARK: - UITableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        self.isFirstTimeUse = false
        return self.elements.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.isFirstTimeUse = false
        return section < self.elements.count ? self.elements[section].count: 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError( "tableView(_:cellForRowAt:) has not been implemented" )
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        false
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if case .delete = editingStyle {
            self.remove( at: indexPath )
        }
    }

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        true
    }

    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        self.move( at: sourceIndexPath, to: destinationIndexPath )
    }

    // MARK: - Private

    /// Perform a batch of updates on the view.
    ///
    /// NOTE: Item reloads must be specified in the separate reloads block and use the post-updates indexPaths
    ///       since -performBatchUpdates does not support simultaneous reloads and moves.
    ///
    /// OPERATION | INDEXPATH
    /// --------- | ---------
    /// reload    | at:   before updates
    /// delete    | at:   before updates
    /// move      | from: before updates
    ///           | to:   after updates
    /// insert    | at:   after updates
    private func performBatch(reloads reloadPaths: [IndexPath]? = nil, updates: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        //dbg( "%@: perform", self.semaphore )
        DispatchQueue.main.perform( group: self.semaphore ) {
            self.tableView?.performBatchUpdates( updates, completion: completion )
            self.collectionView?.performBatchUpdates( updates, completion: completion )
            if let reloadPaths = reloadPaths, !reloadPaths.isEmpty {
                self.collectionView?.reloadItems( at: reloadPaths )
                self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
            }
            //dbg( "%@: done", self.semaphore )
        }
    }

    private func indexPath(for item: E, in sections: [[E]]? = nil, elementsMatch: (E, E) -> Bool) -> IndexPath? {
        self.indexPath( where: { elementsMatch( item, $0 ) }, in: sections )
    }

    private func indexPath(where predicate: (E) -> Bool, in sections: [[E]]? = nil) -> IndexPath? {
        var section = 0
        for sectionItems in sections ?? self.elements {
            if let index = sectionItems.firstIndex( where: predicate ) {
                return IndexPath( item: index, section: section )
            }

            section += 1
        }

        return nil
    }
}
