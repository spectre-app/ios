//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

// NOTE:
// Due to a bug in performBatchUpdates, moving elements from one section to another while deleting the source section
// is not animated due to it triggering a full reloadData. The work-around is to leave the section empty (or remove it separately).
// http://www.openradar.me/48941363
open class DataSource<E: Hashable>: NSObject, UICollectionViewDataSource, UITableViewDataSource {
    private let tableView:         UITableView?
    private let collectionView:    UICollectionView?
    private var elementsBySection: [[E]]
    private var elementsConsumed = false

    public var isEmpty: Bool {
        self.elementsBySection.reduce( true ) { $0 && $1.isEmpty }
    }

    public init(tableView: UITableView? = nil, collectionView: UICollectionView? = nil, sectionsOfElements: [[E]]? = nil) {
        self.tableView = tableView
        self.collectionView = collectionView
        self.elementsBySection = sectionsOfElements ?? []
    }

    // MARK: --- Interface ---

    open func indexPath(for item: E?) -> IndexPath? {
        item.flatMap { self.indexPath( for: $0, in: self.elementsBySection, elementsMatch: { $0 == $1 } ) }
    }

    open func indexPath(for item: E?) -> IndexPath? where E: Identifiable {
        item.flatMap { self.indexPath( for: $0, in: self.elementsBySection, elementsMatch: { $0.id == $1.id } ) }
    }

    open func indexPath(where predicate: (E) -> Bool) -> IndexPath? {
        self.indexPath( where: predicate, in: self.elementsBySection )
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
        // TODO: inline these types
        let s: LazySequence<FlattenSequence<LazyMapSequence<EnumeratedSequence<[[E]]>, LazyMapSequence<EnumeratedSequence<[E]>, (indexPath: IndexPath, element: E)>>>>
                = self.elementsBySection.enumerated().lazy.flatMap {
            let (section, sectionElements) = $0

            return sectionElements.enumerated().lazy.map {
                let (item, element) = $0

                return (indexPath: IndexPath( item: item, section: section ), element: element)
            }
        }
        return AnySequence<(indexPath: IndexPath, element: E)>( s )
    }

    open func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                     reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil) {
        self.update( toElementsBySection, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0 == $1 } )
    }

    open func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                     reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil) where E: Identifiable {
        self.update( toElementsBySection, selected: selectElements, selecting: selectPaths,
                     reload: reloadAll, reloaded: reloadElements, reloading: reloadPaths,
                     animated: animated, completion: completion, elementsMatch: { $0.id == $1.id } )
    }

    private func update(_ toElementsBySection: [[E]], selected selectElements: Set<E?>? = nil, selecting selectPaths: [IndexPath]? = nil,
                        reload reloadAll: Bool = false, reloaded reloadElements: Set<E>? = nil, reloading reloadPaths: [IndexPath]? = nil,
                        animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> ())? = nil, elementsMatch: @escaping (E, E) -> Bool) {
        trc( "updating dataSource:\n%@\n<=\n%@", self.elementsBySection, toElementsBySection )

        if !self.elementsConsumed {
            self.elementsBySection = toElementsBySection
            self.select( selectElements, paths: selectPaths )
            completion?( true )
            return
        }

        self.perform( animated: animated, completion: { success in
            if success {
                self.select( selectElements, paths: selectPaths )
            }

            completion?( success )
        } ) {
            // Check if element values have changed and mark updated paths for reload.
            var reloadPaths = reloadPaths ?? []
            for toElements in toElementsBySection {
                for toElement in toElements {
                    if let fromIndexPath = self.indexPath( for: toElement, in: self.elementsBySection, elementsMatch: elementsMatch ),
                       reloadAll || (reloadElements?.contains( toElement ) ?? false) || self.element( at: fromIndexPath ) != toElement {
                        // Element reload requested or required due to the new element being different from the old.
                        self.elementsBySection[fromIndexPath.section][fromIndexPath.item] = toElement
                        reloadPaths.append( fromIndexPath )
                    }
                }
            }
            if reloadPaths.count > 0 {
                trc( "reload items %@", reloadPaths )
                self.collectionView?.reloadItems( at: reloadPaths )
                self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
            }

            // Check if element layout has changed and apply deletes, inserts & moves required to adopt new layout, in that order.
            if !self.elementsBySection.elementsEqual( toElementsBySection, by: { $0.elementsEqual( $1, by: elementsMatch ) } ) {

                // Add empty dataSource sections for newly introduced sections.
                for toSection in 0..<toElementsBySection.count {
                    if toSection >= self.elementsBySection.count {
                        trc( "insert section %d", toSection )
                        self.elementsBySection.append( [ E ]() )
                        self.collectionView?.insertSections( IndexSet( integer: toSection ) )
                        self.tableView?.insertSections( IndexSet( integer: toSection ), with: .automatic )
                    }
                }

                // Delete dataSource elements no longer reflected in the new sections.
                for (fromSection, fromElements) in self.elementsBySection.enumerated() {
                    for (fromItem, fromElement) in fromElements.enumerated().reversed() {
                        if self.indexPath( for: fromElement, in: toElementsBySection, elementsMatch: elementsMatch ) == nil {
                            let fromIndexPath = IndexPath( item: fromItem, section: fromSection )
                            trc( "delete item %@", fromIndexPath )
                            self.elementsBySection[fromSection].remove( at: fromItem )
                            self.collectionView?.deleteItems( at: [ fromIndexPath ] )
                            self.tableView?.deleteRows( at: [ fromIndexPath ], with: .automatic )
                        }
                    }
                }

                // Reflect the new sections by moving or reloading existing elements and inserting missing ones.
                for (toSection, toElements) in toElementsBySection.enumerated() {
                    for (toItem, toElement) in toElements.enumerated() {
                        if self.indexPath( for: toElement, in: self.elementsBySection, elementsMatch: elementsMatch ) == nil {
                            // New element missing in old dataSource.
                            let toIndexPath   = IndexPath( item: toItem, section: toSection )
                            // NOTE: Moves have not yet been applied, so we don't know the exact indexPath to insert into.
                            // We make a best-effort insertion, ensuring not to overrun the dataSource's section array.
                            // Subsequent move phase should fix any inaccuracies.
                            let fromIndexPath = IndexPath( item: min( toIndexPath.item, self.elementsBySection[toIndexPath.section].endIndex ), section: toIndexPath.section )
                            trc( "insert item %@", fromIndexPath )
                            self.elementsBySection[fromIndexPath.section].insert( toElement, at: fromIndexPath.item )
                            self.collectionView?.insertItems( at: [ fromIndexPath ] )
                            self.tableView?.insertRows( at: [ fromIndexPath ], with: .automatic )
                        }
                    }
                }

                // Reflect the new sections by moving or reloading existing elements and inserting missing ones.
                for (toSection, toElements) in toElementsBySection.enumerated() {
                    for (toItem, toElement) in toElements.enumerated() {
                        if let fromIndexPath = self.indexPath( for: toElement, in: self.elementsBySection, elementsMatch: elementsMatch ) {
                            // New element exists in old dataSource.
                            let toIndexPath = IndexPath( item: toItem, section: toSection )

                            if toIndexPath != fromIndexPath {
                                // New element at different path from old dataSource.
                                trc( "move item %@ -> %@", fromIndexPath, toIndexPath )
                                self.elementsBySection[fromIndexPath.section].remove( at: fromIndexPath.item )
                                self.elementsBySection[toIndexPath.section].insert( toElement, at: toIndexPath.item )
                                self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                                self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                            }
                        }
                    }
                }

                // Remove dataSource sections no longer present in the new sections (should be empty of items now).
                for section in (0..<self.elementsBySection.count).reversed() {
                    if section >= toElementsBySection.count {
                        trc( "delete section %d", section )
                        self.elementsBySection.remove( at: section )
                        self.collectionView?.deleteSections( IndexSet( integer: section ) )
                        self.tableView?.deleteSections( IndexSet( integer: section ), with: .automatic )
                    }
                }
            }

            // Should be a no-op now.
            self.elementsBySection = toElementsBySection
        }
    }

    open func select(_ elements: Set<E?>? = nil, paths: [IndexPath]? = nil, animated: Bool = true) {
        guard elements != nil || paths != nil
        else { return }

        var selectionPaths = paths ?? []
        selectionPaths.append( contentsOf: elements?.compactMap { self.indexPath( for: $0 ) } ?? [] )

        if selectionPaths.isEmpty || self.tableView?.allowsMultipleSelection ?? false || self.collectionView?.allowsMultipleSelection ?? false {
            self.tableView?.indexPathsForSelectedRows?.filter { !selectionPaths.contains( $0 ) }.forEach {
                trc( "deselect item %@", $0 )
                self.tableView?.deselectRow( at: $0, animated: animated )
            }
            self.collectionView?.indexPathsForSelectedItems?.filter { !selectionPaths.contains( $0 ) }.forEach {
                trc( "deselect item %@", $0 )
                self.collectionView?.deselectItem( at: $0, animated: animated )
            }
        }
        else if selectionPaths.count > 1 {
            selectionPaths = [ selectionPaths[0] ]
        }
        selectionPaths.forEach {
            trc( "select item %@", $0 )
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

        self.perform( animated: animated, completion: completion ) {
            self.elementsBySection[indexPath.section].remove( at: indexPath.item )
            self.collectionView?.deleteItems( at: [ indexPath ] )
            self.tableView?.deleteRows( at: [ indexPath ], with: .automatic )
        }
        return true
    }

    @discardableResult
    open func move(at fromIndexPath: IndexPath, to toIndexPath: IndexPath, animated: Bool = true, completion: ((Bool) -> Void)? = nil) -> Bool {
        guard fromIndexPath.section < self.elementsBySection.count && fromIndexPath.item < self.elementsBySection[fromIndexPath.section].count,
              toIndexPath.section < self.elementsBySection.count && toIndexPath.item < self.elementsBySection[toIndexPath.section].count
        else { return false }

        self.perform( animated: animated, completion: completion ) {
            let element = self.elementsBySection[fromIndexPath.section].remove( at: fromIndexPath.item )

            var toItem = toIndexPath.item
            if toIndexPath.section == fromIndexPath.section && toIndexPath.item >= fromIndexPath.item {
                toItem -= 1
            }

            self.elementsBySection[toIndexPath.section].insert( element, at: toItem )
            self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
            self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
        }
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
