// =============================================================================
// Created by Maarten Billemont on 2020-01-02.
// Copyright (c) 2020 Maarten Billemont. All rights reserved.
//
// This file is part of Spectre.
// Spectre is free software. You can modify it under the terms of
// the GNU General Public License, either version 3 or any later version.
// See the LICENSE file for details or consult <http://www.gnu.org/licenses/>.
//
// Note: this grant does not include any rights for use of Spectre's trademarks.
// =============================================================================

import Foundation

// swiftlint:disable line_length
// printf <secret> | openssl enc -[ed] -aes-128-cbc -a -A -K <app.secret> -iv 0
let secrets = (
        app: (
                secret: "",
                salt: "",
                _: ()
        ),
        mpw: (
                salt: "",
                _: ()
        ),
        sentry: (
                dsn: "",
                _: ()
        ),
        countly: (
                private: (
                        key: "",
                        salt: "",
                        _: ()
                ),
                pilot: (
                        key: "",
                        salt: "",
                        _: ()
                ),
                public: (
                        key: "",
                        salt: "",
                        _: ()
                )
        ),
        freshchat: (
                app: "",
                key: "",
                _: ()
        ),
        stacksift: (
                key: "",
                _: ()
        )
)
