//
// Created by Maarten Billemont on 2019-11-08.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import UIKit

extension UITableViewCell {
    static func dequeue<C: UITableViewCell>(from tableView: UITableView, indexPath: IndexPath, _ initializer: ((C) -> ())? = nil) -> Self {
        let cell = tableView.dequeueReusableCell( withIdentifier: NSStringFromClass( self ), for: indexPath ) as! C

        if let initialize = initializer {
            initialize( cell )
        }

        return cell as! Self
    }
}

extension UITableView {

    func register(_ type: UITableViewCell.Type, nib: UINib? = nil) {
        if let nib = nib {
            self.register( nib, forCellReuseIdentifier: NSStringFromClass( type ) )
        }
        else {
            self.register( type, forCellReuseIdentifier: NSStringFromClass( type ) )
        }
    }
}
