//
//  AppState+Radio.swift
//  StoneBC
//
//  Adds Rally Radio to AppState
//

import Foundation

extension AppState {
    var radioViewModel: RadioViewModel {
        if _radioViewModel == nil {
            _radioViewModel = RadioViewModel()
        }
        return _radioViewModel!
    }

    // Stored as optional to avoid creating until needed
    private static var _storage = [ObjectIdentifier: RadioViewModel]()

    private var _radioViewModel: RadioViewModel? {
        get { Self._storage[ObjectIdentifier(self)] }
        set { Self._storage[ObjectIdentifier(self)] = newValue }
    }
}
