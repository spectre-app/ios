//
// Created by Maarten Billemont on 2019-10-20.
// Copyright (c) 2019 Lyndir. All rights reserved.
//

import Foundation

public enum MPProgramState {
    static var activeStates = [ MPProgramState: Int ]()

    case sideEffect

    public var isActive: Bool {
        MPProgramState.activeStates[self] ?? 0 > 0
    }

    public func perform(_ action: () -> Void) {
        MPProgramState.activeStates[self] = (MPProgramState.activeStates[self] ?? 0) + 1
        defer { MPProgramState.activeStates[self] = (MPProgramState.activeStates[self] ?? 0) - 1 }

        action()
    }
}
