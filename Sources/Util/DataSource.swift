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
import OrderedCollections

class DataSource<S: Hashable, E: Hashable> {
    private let queue = DispatchQueue.global( qos: .userInitiated )
    private let tableSource:      TableSource?
    private let collectionSource: CollectionSource?

    public var isFirstTimeUse = true
    public var isEmpty: Bool {
        self.queue.sync {
            (self.tableSource?.snapshot().numberOfItems ?? self.collectionSource?.snapshot().numberOfItems ?? 0) == 0
        }
    }
    public var selectedItems: [E] {
        get {
            self.tableSource?.tableView?.indexPathsForSelectedRows?
                .compactMap { self.tableSource?.itemIdentifier( for: $0 ) } ??
            self.collectionSource?.collectionView?.indexPathsForSelectedItems?
                .compactMap { self.collectionSource?.itemIdentifier( for: $0 ) } ??
            []
        }
        set {
            self.select( items: newValue )
        }
    }

    public init(tableView: UITableView,
                cellProvider: @escaping (_ tableView: UITableView, _ indexPath: IndexPath, _ item: E) -> UITableViewCell?,
                editor: @escaping (E) -> ((UITableViewCell.EditingStyle) -> Void)? = { _ in nil }) {
        self.tableSource = TableSource( tableView: tableView, cellProvider: cellProvider, editor: editor )
        self.collectionSource = nil
        LeakRegistry.shared.register( self )
    }

    public init(collectionView: UICollectionView,
                cellProvider: @escaping (_ collectionView: UICollectionView, _ indexPath: IndexPath, _ item: E) -> UICollectionViewCell?) {
        self.tableSource = nil
        self.collectionSource = CollectionSource( collectionView: collectionView, cellProvider: cellProvider )
        LeakRegistry.shared.register( self )
    }

    func snapshot() -> NSDiffableDataSourceSnapshot<S, E>? {
        self.queue.sync {
            self.tableSource?.snapshot() ?? self.collectionSource?.snapshot()
        }
    }

    func item(for indexPath: IndexPath) -> E? {
        self.queue.sync {
            self.tableSource?.itemIdentifier( for: indexPath ) ?? self.collectionSource?.itemIdentifier( for: indexPath )
        }
    }

    func apply(_ items: [S: [E]], animatingDifferences: Bool = true, completion: (() -> Void)? = nil)
            where S: Comparable {
        var snapshot = NSDiffableDataSourceSnapshot<S, E>()
        snapshot.appendSections( items.keys.sorted() )
        for (section, items) in items {
            snapshot.appendItems( OrderedSet( items ).elements, toSection: section )
        }
        self.apply( snapshot, animatingDifferences: animatingDifferences, completion: completion )
    }

    func apply(_ snapshot: NSDiffableDataSourceSnapshot<S, E>, animatingDifferences: Bool = true, completion: (() -> Void)? = nil) {
        self.queue.async {
            self.tableSource?.apply( snapshot, animatingDifferences: animatingDifferences, completion: completion )
            self.collectionSource?.apply( snapshot, animatingDifferences: animatingDifferences, completion: completion )
        }
    }

    func select(item element: E?, delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled) {
        if let element = element {
            self.select( items: [ element ], delegation: delegation, animated: animated )
        }
        else {
            self.select( items: [], delegation: delegation, animated: animated )
        }
    }

    func select(items elements: [E], delegation: Bool = true, animated: Bool = UIView.areAnimationsEnabled) {
        self.tableSource?.tableView?.requestSelection(
                at: elements.compactMap { self.tableSource?.indexPath( for: $0 ) }, delegation: delegation, animated: animated )
        self.collectionSource?.collectionView?.requestSelection(
                at: elements.compactMap { self.collectionSource?.indexPath( for: $0 ) }, delegation: delegation, animated: animated )
    }

    class TableSource: UITableViewDiffableDataSource<S, E> {
        weak var    tableView: UITableView?
        private let editor:    (E) -> ((UITableViewCell.EditingStyle) -> Void)?

        init(tableView: UITableView, cellProvider: @escaping CellProvider,
             editor: @escaping (E) -> ((UITableViewCell.EditingStyle) -> Void)?) {
            self.tableView = tableView
            self.editor = editor
            super.init( tableView: tableView, cellProvider: cellProvider )
            LeakRegistry.shared.register( self )
        }

        // MARK: - UITableViewDataSource

        public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            self.itemIdentifier( for: indexPath ).flatMap( self.editor ) != nil
        }

        public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            self.itemIdentifier( for: indexPath ).flatMap( self.editor )?( editingStyle )
        }
    }

    class CollectionSource: UICollectionViewDiffableDataSource<S, E> {
        weak var collectionView: UICollectionView?

        override init(collectionView: UICollectionView, cellProvider: @escaping CellProvider) {
            self.collectionView = collectionView
            super.init( collectionView: collectionView, cellProvider: cellProvider )
            LeakRegistry.shared.register( self )
        }

        // MARK: - UICollectionViewDataSource
    }
}

enum NoSections: Hashable, Comparable {
    case items
}
