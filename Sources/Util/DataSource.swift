//
// Created by Maarten Billemont on 2019-07-22.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

open class DataSource<E: Hashable>: NSObject, UICollectionViewDataSource, UITableViewDataSource {
    private let tableView:         UITableView?
    private let collectionView:    UICollectionView?
    private var elementsBySection: [[E?]]
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
        self.indexPath( for: item, in: self.elementsBySection )
    }

    open func indexPath(where predicate: (E?) -> Bool) -> IndexPath? {
        self.indexPath( where: predicate, in: self.elementsBySection )
    }

    open func firstElement(where predicate: (E?) -> Bool) -> E? {
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

    open func elements() -> AnySequence<(indexPath: IndexPath, element: E?)> {
        // TODO: inline these types
        let s: LazySequence<FlattenSequence<LazyMapSequence<EnumeratedSequence<[[E?]]>, LazyMapSequence<EnumeratedSequence<[E?]>, (indexPath: IndexPath, element: E?)>>>>
                = self.elementsBySection.enumerated().lazy.flatMap {
            let (section, sectionElements) = $0

            return sectionElements.enumerated().lazy.map {
                let (item, element) = $0

                return (indexPath: IndexPath( item: item, section: section ), element: element)
            }
        }
        return AnySequence<(indexPath: IndexPath, element: E?)>( s )
    }

    open func update(_ elementsBySection: [[E?]],
                     reloadItems: Bool = false, reloadPaths: [IndexPath]? = nil, reloadElements: [E?]? = nil,
                     animated: Bool = UIView.areAnimationsEnabled, completion: ((Bool) -> Void)? = nil) {
        trc( "updating dataSource:\n%@\n<=\n%@", self.elementsBySection, elementsBySection )

        if !self.elementsConsumed {
            self.elementsBySection = elementsBySection
            completion?( true )
            return
        }

        self.perform( animated: animated, completion: completion ) {
            let updateIncrementally = !animated
            var reloadPaths         = reloadPaths ?? []

            if elementsBySection == self.elementsBySection {
                for (section, elements) in self.elementsBySection.enumerated() {
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
                for section in (0..<max( self.elementsBySection.count, elementsBySection.count )).reversed() {
                    if section >= elementsBySection.count {
                        trc( "delete section %d", section )
                        if updateIncrementally {
                            self.elementsBySection.remove( at: section )
                        }
                        self.collectionView?.deleteSections( IndexSet( integer: section ) )
                        self.tableView?.deleteSections( IndexSet( integer: section ), with: .automatic )
                    }
                }
                for section in 0..<max( self.elementsBySection.count, elementsBySection.count ) {
                    if section >= self.elementsBySection.count {
                        trc( "insert section %d", section )
                        if updateIncrementally {
                            self.elementsBySection.append( [ E? ]() )
                        }
                        self.collectionView?.insertSections( IndexSet( integer: section ) )
                        self.tableView?.insertSections( IndexSet( integer: section ), with: .automatic )
                    }
                }

                // Figure out how the section items have changed.
                for (section, elements) in elementsBySection.enumerated() {
                    for (item, element) in elements.enumerated() {
                        let toIndexPath = IndexPath( item: item, section: section )
                        if let fromIndexPath = self.indexPath( for: element, in: self.elementsBySection ) {
                            if toIndexPath != fromIndexPath {
                                trc( "move item %@ -> %@", fromIndexPath, toIndexPath )
                                if updateIncrementally {
                                    self.elementsBySection[fromIndexPath.section].remove( at: fromIndexPath.item )
                                    self.elementsBySection[toIndexPath.section].insert( element, at: toIndexPath.item )
                                }
                                self.collectionView?.moveItem( at: fromIndexPath, to: toIndexPath )
                                self.tableView?.moveRow( at: fromIndexPath, to: toIndexPath )
                            }
                            else if reloadItems || reloadElements?.contains( where: { $0 == element } ) ?? false {
                                trc( "reload item %@", fromIndexPath )
                                if updateIncrementally {
                                    self.elementsBySection[fromIndexPath.section][fromIndexPath.item] = element
                                }
                                reloadPaths.append( fromIndexPath )
                            }
                        }
                        else {
                            trc( "insert item %@", toIndexPath )
                            if updateIncrementally {
                                self.elementsBySection[toIndexPath.section].insert( element, at: toIndexPath.item )
                            }
                            self.collectionView?.insertItems( at: [ toIndexPath ] )
                            self.tableView?.insertRows( at: [ toIndexPath ], with: .automatic )
                        }
                    }
                }

                // Add inserted rows.
                for (section, elements) in self.elementsBySection.enumerated() {
                    for (item, element) in elements.enumerated().reversed() {
                        let fromIndexPath = IndexPath( item: item, section: section )
                        if self.indexPath( for: element, in: elementsBySection ) == nil {
                            trc( "delete item %@", fromIndexPath )
                            if updateIncrementally {
                                self.elementsBySection[section].remove( at: item )
                            }
                            self.collectionView?.deleteItems( at: [ fromIndexPath ] )
                            self.tableView?.deleteRows( at: [ fromIndexPath ], with: .automatic )
                        }
                    }
                }
            }

            self.elementsBySection = elementsBySection

            if reloadPaths.count > 0 {
                trc( "reload items %@", reloadPaths )
                self.collectionView?.reloadItems( at: reloadPaths )
                self.tableView?.reloadRows( at: reloadPaths, with: .automatic )
            }
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
