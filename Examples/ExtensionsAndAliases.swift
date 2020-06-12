//
//  OAuthSwiftExtensions.swift
//  Examples
//
//  Created by Robert Vaessen on 5/29/20.
//  Copyright © 2020 Robert Vaessen. All rights reserved.
//

import Foundation
import OAuthSwift

typealias JSONArray = Array<AnyObject>
typealias JSONDictionary = Dictionary<String, AnyObject>

extension OAuthSwiftError {
    public var name: String {
        switch self {
        case .configurationError: return "configurationError"
        case .tokenExpired: return "tokenExpired"
        case .missingState: return "missingState"
        case .stateNotEqual: return "stateNotEqual"
        case .serverError: return "serverError"
        case .encodingError: return "encodingError"
        case .requestCreation: return "requestCreation"
        case .missingToken: return "missingToken"
        case .retain: return "retain"
        case .requestError: return "requestError"
        case .slowDown : return "slowDown"
        case .accessDenied : return "accessDenied"
        case .authorizationPending: return "authorizationPending"
        case .cancelled : return "cancelled"
        }
    }
}
