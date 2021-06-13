//==============================================================================
// Created by Maarten Billemont on 2019-07-18.
// Copyright (c) 2019 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
//==============================================================================

import Foundation

class Graph<E: Hashable>: CustomStringConvertible {
    internal var links = Set<Link<E>>()

    var description: String {
        self.links.reduce( "" ) { $0 + " - \($1)\n" }
    }

    @discardableResult
    func link<S: Sequence>(value: E, to links: S) -> Int
            where S.Element == (target: E, cost: Double) {
        var newLinks = 0
        for link in links {
            if self.links.update( with: Link( from: value, to: link.target, cost: link.cost ) ) == nil {
                newLinks += 1
            }
        }

        return newLinks
    }

    func find(from root: E, _ found: (E) -> Bool, budget: Double = Double.greatestFiniteMagnitude) -> E? {
        Graph.path( from: root, find: found, links: { node in
            self.links.reduce( [ Link<E> ]() ) { links, link in
                link.from == node ? links + [ link ]: links
            }
        }, budget: budget )?.target
    }

    public static func path<E: Hashable, S: Sequence>(
            from root: E, find found: (E) -> Bool, neighbours: (E) -> S,
            cost: (E, E) -> Double?, budget: Double = Double.greatestFiniteMagnitude) -> Path<E>?
            where S.Element == E {

        self.path( from: root, find: found, links: { node in
            neighbours( node ).reduce( [ Link<E> ]() ) { neighbours, neighbour in
                if let cost = cost( node, neighbour ) {
                    return neighbours + [ Link( from: node, to: neighbour, cost: cost ) ]
                }
                else {
                    return neighbours
                }
            }
        }, budget: budget )
    }

    public static func path<E: Hashable, S: Sequence>(
            from root: E, find found: (E) -> Bool, links: (E) -> S,
            budget: Double = Double.greatestFiniteMagnitude) -> Path<E>?
            where S.Element == Link<E> {

        // Test the root.
        if (found( root )) {
            //dbg( "found root: %@", root )
            return Path( target: root, cost: 0 )
        }

        // Initialize breath-first.
        var testedNodes = Set<E>()
        var testPaths   = [ Path<E> ]()
        testPaths.append( Path( target: root, cost: 0 ) )
        testedNodes.insert( root )

        // Search breath-first.
        while (!testPaths.isEmpty) {
            let testPath = testPaths.removeFirst()

            // Check each neighbour.
            for link in links( testPath.target ) {
                guard let neighbour = link.other( than: testPath.target )
                else {
                    // Link was not for target.
                    continue
                }

                if !testedNodes.insert( neighbour ).inserted {
                    // Neighbour was already tested.
                    continue
                }

                let neighbourCost = testPath.cost + link.cost
                if neighbourCost > budget {
                    // Stepping to neighbour from here would exceed maximum cost.
                    //dbg( "neighbour exceeds maximum cost (%f > %f): %@", neighbourCost, budget, neighbour )
                    continue
                }

                // Did we find the target?
                let neighbourPath = Path( parent: testPath, target: neighbour, cost: neighbourCost )
                if (found( neighbour )) {
                    //dbg( "found neighbour at cost %f: %@", neighbourCost, neighbour )
                    return neighbourPath
                }
                //dbg( "intermediate neighbour at cost %f: %@", neighbourCost, neighbour )

                // Neighbour is not the target, add it for testing its neighbours later.
                testPaths.append( neighbourPath )
            }
        }

        return nil
    }

    public class Link<E: Hashable>: Hashable, CustomStringConvertible {
        internal let from:        E
        internal let to:          E
        internal let cost:        Double
        public var   description: String {
            "[\(from)]--- \(cost) ---[\(to)]"
        }

        public init(from: E, to: E, cost: Double) {
            self.from = from
            self.to = to
            self.cost = cost
        }

        public func other(than other: E) -> E? {
            if from == other {
                return to
            }
            if to == other {
                return from
            }
            return nil
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine( from )
            hasher.combine( to )
        }

        public static func ==(lhs: Link<E>, rhs: Link<E>) -> Bool {
            lhs.from == rhs.from && lhs.to == rhs.to
        }
    }

    public class Path<E: Hashable> {
        internal var parent: Path<E>?
        internal let target: E
        internal let cost:   Double

        public init(parent: Path<E>? = nil, target: E, cost: Double) {
            self.parent = parent
            self.target = target
            self.cost = cost
        }
    }
}
