//
// Created by Maarten Billemont on 2019-05-11.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

class MPMarshal {
    public static let shared = MPMarshal()

    // MARK: --- Interface ---

    public func loadFiles(_ completion: @escaping ([UserInfo]?) -> Void) {
        DispatchQueue.mpw.perform {
            do {
                var users     = [ UserInfo ]()
                let documents = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask,
                                                             appropriateFor: nil, create: true )
                for documentPath in try FileManager.default.contentsOfDirectory( atPath: documents.path ) {
                    if let document = FileManager.default.contents( atPath: documentPath ), !document.isEmpty,
                       let userDocument = String( data: document, encoding: .utf8 ),
                       let userInfo = mpw_marshal_read_info( userDocument )?.pointee, userInfo.format != .none,
                       let fullName = String( utf8String: userInfo.fullName ) {
                        users.append( UserInfo(
                                document: userDocument,
                                format: userInfo.format,
                                algorithm: userInfo.algorithm,
                                fullName: fullName,
                                avatar: .avatar_0,
                                keyID: String( utf8String: userInfo.keyID ),
                                redacted: userInfo.redacted,
                                date: Date( timeIntervalSince1970: TimeInterval( userInfo.date ) )
                        ) )
                    }
                }

                completion( users )
            }
            catch let e {
                err( "caught: \(e)" )
                completion( nil )
            }
        }
    }

    public func saveToFile(user: MPUser) {
        DispatchQueue.mpw.perform {
            do {
                let format         = MPMarshalFormat.default
                let error          = UnsafeMutablePointer<MPMarshalError>.allocate( capacity: 1 )
                let marshalledUser = UnsafeMutablePointer<MPMarshalledUser>.allocate( capacity: 1 )
                var document: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
                let success        = mpw_marshal_write( document, format, marshalledUser, error )
                inf( "saveToFile(\(user.fullName)): \(success), \(String( utf8String: error.pointee.description ) ?? "n/a")" )

                if success,
                   let formatExtension = String( utf8String: mpw_marshal_format_extension( format ) ),
                   let document = document?.pointee,
                   let userDocument = String( utf8String: document ) {
                    let documentPath = try FileManager.default.url( for: .documentDirectory, in: .userDomainMask,
                                                                    appropriateFor: nil, create: true )
                                                              .appendingPathComponent( user.fullName, isDirectory: false )
                                                              .appendingPathExtension( formatExtension ).path
                    if FileManager.default.createFile( atPath: documentPath, contents: userDocument.data( using: .utf8 ) ) {
                        inf( "written to: \(documentPath)" )
                    }
                }
            }
            catch let e {
                err( "caught: \(e)" )
            }
        }
    }

    class UserInfo {
        public let document:  String
        public let format:    MPMarshalFormat
        public let algorithm: MPAlgorithmVersion
        public let fullName:  String
        public let avatar:    MPUser.Avatar
        public let keyID:     String?
        public let redacted:  Bool
        public let date:      Date

        init(document: String, format: MPMarshalFormat, algorithm: MPAlgorithmVersion, fullName: String, avatar: MPUser.Avatar,
             keyID: String?, redacted: Bool, date: Date) {
            self.document = document
            self.format = format
            self.algorithm = algorithm
            self.fullName = fullName
            self.avatar = avatar
            self.keyID = keyID
            self.redacted = redacted
            self.date = date
        }

        public func authenticate(masterPassword: String, _ completion: @escaping (MPUser?, MPMarshalError) -> Void) {
            DispatchQueue.mpw.perform {
                masterPassword.withCString { masterPassword in
                    let error = UnsafeMutablePointer<MPMarshalError>.allocate( capacity: 1 )
                    if let marshalledUser = mpw_marshal_read( self.document, self.format, masterPassword, error )?.pointee {
                        completion( MPUser(
                                named: String( utf8String: marshalledUser.fullName ) ?? self.fullName,
                                avatar: MPUser.Avatar( rawValue: Int( marshalledUser.avatar ) ) ?? .avatar_0,
                                algorithm: marshalledUser.algorithm,
                                defaultType: marshalledUser.defaultType,
                                masterKeyID: self.keyID
                        ), error.pointee )
                    }
                    else {
                        completion( nil, error.pointee )
                    }
                }
            }
        }
    }
}
