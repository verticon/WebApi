//
//  OAuthViewController.swift
//  Examples
//
//  Created by Robert Vaessen on 5/27/20.
//  Copyright © 2020 Robert Vaessen. All rights reserved.
//

import UIKit
import OAuthSwift

class OAuthViewController: ApiViewController {

    var authorization: OAuth2Swift?

    struct AuthorizationParameters {
        let consumerKey: String
        let consumerSecret: String
        let authorizeUrl: String
        let accessTokenUrl: String
        let redirectUri: String
        let responseType: String
        let scope: String
        let state: String
    }

    func authorize(serviceName: String, parameters: AuthorizationParameters, tokenKey: String, tokenSecretKey: String, callback: @escaping (Bool) -> ()) {
        guard self.authorization == nil else { callback(true); return }

        log("\(serviceName): Authorizing access")

        let authorization = OAuth2Swift(consumerKey: parameters.consumerKey, consumerSecret: parameters.consumerSecret,
                                        authorizeUrl: parameters.authorizeUrl, accessTokenUrl: parameters.accessTokenUrl,
                                        responseType: parameters.responseType)
        authorization.allowMissingStateCheck = true
        authorization.authorizeURLHandler = SafariURLHandler(viewController: self, oauthSwift: authorization)

        if  let token = UserDefaults.standard.string(forKey: tokenKey),
            let tokenSecret = UserDefaults.standard.string(forKey: tokenSecretKey) {
            self.log("\(serviceName): Using stored credentials")

            authorization.client.credential.oauthToken = token
            authorization.client.credential.oauthTokenSecret = tokenSecret
            self.authorization = authorization
            callback(true)
        }
        else {
            self.log("\(serviceName): Obtaining credentials from server")
            
            guard let callbackURL = URL(string: parameters.redirectUri) else { log("\(serviceName): Invalid redirect URI - \(parameters.redirectUri)"); return }
            
            authorization.authorize(withCallbackURL: callbackURL, scope: parameters.scope, state: parameters.state) { result in
                switch result {

                case .success(let (credential, _, _)):
                    self.log("\(serviceName): Authorization was granted.")
                    UserDefaults.standard.set(credential.oauthToken, forKey: tokenKey)
                    UserDefaults.standard.set(credential.oauthTokenSecret, forKey: tokenSecretKey)
                    self.authorization = authorization
                    callback(true)

                case .failure(let error):
                    self.log("\(serviceName): Authorization was denied - \(error)");
                    callback(false)
}
            }
        }
    }
}
