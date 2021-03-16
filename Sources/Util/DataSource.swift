//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

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
open class DataSource<E: Hashable>: NSObject, UICollectionViewDataSource, UITableViewDataSource {
    private let semaphore        = DispatchGroup()
    private let queue            = DispatchQueue( label: "DataSource" )
    private var elementsBySection: [[E]]
    private var elementsConsumed = false
    private weak var tableView:      UITableView?
    private weak var collectionView: UICollectionView?

    public var isEmpty: Bool {
        self.elementsBySection.reduce( true ) { $0 && $1.isEmpty }
    }

    public init(tableView: UITableView, sectionsOfElements: [[E]] = []) {
        self.tableView = tableView
        self.collectionView = nil
        self.elementsBySection = sectionsOfElements
    }

    public init(collectionView: UICollectionView, sectionsOfElements: [[E]] = []) {
        self.tableView = nil
        self.collectionView = collectionView
        self.elementsBySection = sectionsOfElements
    }

    // MARK: --- Interface ---

    open func count(section: Int? = nil) -> Int {
        if let section = section {
            return self.elementsBySection[section].count
        }
        else {
            return self.elementsBySection.reduce( 0 ) { $0 + $1.count }
        }
    }

    open func indexPath(for item: E?) -> IndexPath? {
        item.flatMap { self.indexPath( for: $0, in: self.elementsBySection, elementsMatch: { $0 == $1 } ) }
    }

    open func indexPath(for item: E?) -> IndexPath? where E: Identifiable {
        item.flatMap { self.indexPath( for: $0, in: self.elementsBySection, elementsMatch: { $0.id == $1.id } ) }
    }

    open func indexPath(where predicate: (E) -> Bool) -> IndexPath? {
        self.indexPath( where: predicate, in: self.elementsBySection )
    }

    open func firstElement(section: Int? = nil) -> E? {
        if let section = section {
            return self.elementsBySection[section].first
        }
        else {
            return self.elementsBySection.reduce( nil ) { $0 ?? $1.first }
        }
    }

    open func firstElement(where predicate: (E) -> Bool) -> E? {
        self.elementsBySection.flatMap { $0 }.first( where: predicate ).flatMap { $0 }
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
                section < self.elementsBySection.count && item < self.elementsBySection[section].count ?
                self.elementsBySection[section][item]: nil
    }

    open func elements() -> AnySequence<(indexPath: IndexPath, element: E)> {
        AnySequence( self.elementsBySection.enumerated().lazy.flatMap {
            (enumeratedSection) -> LazyMapSequence<EnumeratedSequence<[E]>, (indexPath: IndexPath, element: E)> in
            let (section, sectionElements) = enumeratedSection

            return sectionElements.enumerated().lazy.map { (enumeratedElement) in
                let (item, element) = enumeratedElement

                return (indexPath: IndexPath( item: item, section: section ), element: element)
            }
        } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    open func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                     reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil) {
        self.update( toElementsBySection, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0 == $1 } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    open func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                     reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil) where E: Identifiable {
        self.update( toElementsBySection, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0.id == $1.id } )
    }

    // Note: IndexPath parameters should represent element paths as in the new dataSource.
    private func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                        reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                        animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil, elementsMatch: @escaping (E, E) -> Bool) {
        self.queue.sync {
            self.semaphore.wait()
            self.semaphore.enter()
        }

        //dbg( "updating dataSource:\n%@\n<=\n%@", self.elementsBySection, toElementsBySection )

        if !self.elementsConsumed || !animated {
            DispatchQueue.main.perform( group: self.semaphore ) {
                self.elementsBySection = toElementsBySection
                if self.elementsConsumed {
                    self.tableView?.reloadData()
                    self.collectionView?.reloadData()
                }
                self.select( selectElements, paths: selectPaths )
                self.semaphore.leave()
                completion?( true )
            }
            return
        }

        // RELOAD: Check if element values have changed and mark updated paths for reload.
        var reloadPaths = reloadPaths ?? []
        for (toSection, toElements) in toElementsBySection.enumerated() {
            for (toItem, toElement) in toElements.enumerated() {
                let toIndexPath = IndexPath( item: toItem, section: toSection )
                if reloadAll || (reloadElements?.contains( toElement ) ?? false) || {
                    let fromElement = self.firstElement( where: { elementsMatch( $0, toElement ) } );
                    return fromElement != nil && fromElement != toElement }() {
                    // Element reload requested or required due to the new element being different from the old.
                    reloadPaths.append( toIndexPath )
                }
            }
        }

        self.performBatchUpdates {
            // OPERATION | INDEXPATH
            // --------- | ---------
            // reload    | at:   before updates
            // delete    | at:   before updates
            // move      | from: before updates
            //           | to:   after updates
            // insert    | at:   after updates

            // Check if element layout has changed and apply deletes, inserts & moves required to adopt new layout, in that order.
            if !self.elementsBySection.elementsEqual( toElementsBySection, by: { $0.elementsEqual( $1, by: elementsMatch ) } ) {
                // Remove dataSource sections no longer present in the new sections (should be empty of items now).
                for section in (0..<self.elementsBySection.count).reversed()
                    where section >= toElementsBySection.count {
                    //dbg( "delete section %d", section )
                    self.elementsBySection.remove( at: section )
                    self.collectionView?.deleteSections( IndexSet( integer: section ) )
                    self.tableView?.deleteSections( IndexSet( integer: section ), with: .automatic )
                }

                // Add empty dataSource sections for newly introduced sections.
                for toSection in 0..<toElementsBySection.count
                    where toSection >= self.elementsBySection.count {
                    //dbg( "insert section %d", toSection )
                    self.elementsBySection.append( [ E ]() )
                    self.collectionView?.insertSections( IndexSet( integer: toSection ) )
                    self.tableView?.insertSections( IndexSet( integer: toSection ), with: .automatic )
                }

                // DELETE/MOVE: Delete dataSource elements no longer reflected in the new sections.
                for (fromSection, fromElements) in self.elementsBySection.enumerated() {
                    for (fromItem, fromElement) in fromElements.enumerated().reversed() {
                        let fromIndexPath = IndexPath( item: fromItem, section: fromSection )
                        if let toIndexPath = self.indexPath( for: fromElement, in: toElementsBySection, elementsMatch: elementsMatch ) {
                            //dbg( "move item %@ -> %@", fromIndexPath, toIndexPath )
                            self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                            self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                        }
                        else {
                            //dbg( "delete item %@", fromIndexPath )
                            self.collectionView?.deleteItems( at: [ fromIndexPath ] )
                            self.tableView?.deleteRows( at: [ fromIndexPath ], with: .automatic )
                        }
                    }
                }

                // INSERT: Reflect the new sections by moving or reloading existing elements and inserting missing ones.
                for (toSection, toElements) in toElementsBySection.enumerated() {
                    for (toItem, toElement) in toElements.enumerated()
                        where self.indexPath( for: toElement, in: self.elementsBySection, elementsMatch: elementsMatch ) == nil {
                        // New element missing in old dataSource.
                        let toIndexPath = IndexPath( item: toItem, section: toSection )
                        //dbg( "insert item %@", toIndexPath )
                        self.collectionView?.insertItems( at: [ toIndexPath ] )
                        self.tableView?.insertRows( at: [ toIndexPath ], with: .automatic )
                    }
                }
            }

            self.elementsBySection = toElementsBySection
        } completion: { success in
            if success {
                // We reload after updates since it's illegal to move & reload an indexPath at the same time.
                if !reloadPaths.isEmpty {
                    //dbg( "reload items %@", reloadPaths )
                    self.collectionView?.reloadItems( at: reloadPaths )
                    self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
                }

                self.select( selectElements, paths: selectPaths )
            }

            self.semaphore.leave()
            completion?( success )
        }
    }

    open func select(_ elements: Set<E?>? = nil, paths: [IndexPath]? = nil, animated: Bool = true) {
        guard elements != nil || paths != nil
        else { return }

        var selectionPaths = paths ?? []
        selectionPaths.append( contentsOf: elements?.compactMap { self.indexPath( for: $0 ) } ?? [] )

        if selectionPaths.isEmpty || self.tableView?.allowsMultipleSelection ?? false || self.collectionView?.allowsMultipleSelection ?? false {
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
        selectionPaths.forEach {
            //dbg( "select item %@", $0 )
            self.tableView?.selectRow( at: $0, animated: animated, scrollPosition: .middle )
            self.collectionView?.selectItem( at: $0, animated: animated, scrollPosition: .centeredVertically )
        }
    }

    @discardableResult
    open func remove(_ item: E, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        self.remove( at: self.indexPath( for: item ) )
    }

    @discardableResult
    open func remove(at indexPath: IndexPath?, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard let indexPath = indexPath,
              indexPath.section < self.elementsBySection.count && indexPath.item < self.elementsBySection[indexPath.section].count
        else { return false }

        self.performBatchUpdates {
            self.elementsBySection[indexPath.section].remove( at: indexPath.item )
            self.collectionView?.deleteItems( at: [ indexPath ] )
            self.tableView?.deleteRows( at: [ indexPath ], with: .automatic )
        } completion: { completion?( $0 ) }
        return true
    }

    @discardableResult
    open func move(at fromIndexPath: IndexPath, to toIndexPath: IndexPath, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard fromIndexPath.section < self.elementsBySection.count && fromIndexPath.item < self.elementsBySection[fromIndexPath.section].count,
              toIndexPath.section < self.elementsBySection.count && toIndexPath.item < self.elementsBySection[toIndexPath.section].count
        else { return false }

        self.performBatchUpdates {
            let element = self.elementsBySection[fromIndexPath.section].remove( at: fromIndexPath.item )

            var toItem = toIndexPath.item
            if toIndexPath.section == fromIndexPath.section && toIndexPath.item >= fromIndexPath.item {
                toItem -= 1
            }

            self.elementsBySection[toIndexPath.section].insert( element, at: toItem )
            self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
            self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
        } completion: { completion?( $0 ) }
        return true
    }

    // MARK: --- UICollectionViewDataSource ---

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        self.elementsConsumed = true
        return self.elementsBySection.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.elementsConsumed = true
        return section < self.elementsBySection.count ? self.elementsBySection[section].count: 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError( "collectionView(_:cellForItemAt:) has not been implemented" )
    }

    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        false
    }

    public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        self.move( at: sourceIndexPath, to: destinationIndexPath )
    }

    // MARK: --- UITableViewDataSource ---

    public func numberOfSections(in tableView: UITableView) -> Int {
        self.elementsConsumed = true
        return self.elementsBySection.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.elementsConsumed = true
        return section < self.elementsBySection.count ? self.elementsBySection[section].count: 0
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

    // MARK: --- Private ---

    private func performBatchUpdates(_ updates: @escaping () -> (), completion: ((Bool) -> ())? = nil) {
        DispatchQueue.main.perform( group: self.semaphore ) {
            self.tableView?.performBatchUpdates( updates, completion: completion )
            self.collectionView?.performBatchUpdates( updates, completion: completion )
        }
    }

    private func indexPath(for item: E, in sections: [[E]]? = nil, elementsMatch: (E, E) -> Bool) -> IndexPath? {
        self.indexPath( where: { elementsMatch( item, $0 ) }, in: sections )
    }

    private func indexPath(where predicate: (E) -> Bool, in sections: [[E]]? = nil) -> IndexPath? {
        var section = 0
        for sectionItems in sections ?? self.elementsBySection {
            if let index = sectionItems.firstIndex( where: predicate ) {
                return IndexPath( item: index, section: section )
            }

            section += 1
        }

        return nil
    }
}
