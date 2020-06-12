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

    private(set) var authorization: OAuthSwift?

    // **********************************************************************************************************************************
    //
    // **********************************************************************************************************************************

    private func tokenKey(for serviceName: String) -> String { return "\(serviceName)TokenKey" }
    private func tokenSecretKey(for serviceName: String) -> String { return "\(serviceName)TokenSecretKey" }
    private func refreshTokenKey(for serviceName: String) -> String { return "\(serviceName)RefreshTokenKey" }

    private func storeCredentials(for serviceName: String, _ credentials: OAuthSwiftCredential) {
        self.storeCredentials(serviceName: serviceName, oauthToken: credentials.oauthToken, oauthTokenSecret: credentials.oauthTokenSecret, oauthRefreshToken: credentials.oauthRefreshToken)
    }
    private func storeCredentials(serviceName: String, oauthToken: String, oauthTokenSecret: String, oauthRefreshToken: String) {
        UserDefaults.standard.set(oauthToken, forKey: tokenKey(for: serviceName))
        UserDefaults.standard.set(oauthTokenSecret, forKey: tokenSecretKey(for: serviceName))
        UserDefaults.standard.set(oauthRefreshToken, forKey: refreshTokenKey(for: serviceName))
    }

    private func retrieveToken(for serviceName: String) -> String? { return retrieveCredential(forKey: tokenKey(for: serviceName)) }
    private func retrieveTokenSecret(for serviceName: String) -> String? { return retrieveCredential(forKey: tokenSecretKey(for: serviceName)) }
    private func retrieveRefreshToken(for serviceName: String) -> String? { return retrieveCredential(forKey: refreshTokenKey(for: serviceName)) }
    private func retrieveCredential(forKey: String) -> String? {
        if let credential = UserDefaults.standard.string(forKey: forKey), credential.count > 0 { return credential }
        return nil
    }

    // **********************************************************************************************************************************
    //
    // **********************************************************************************************************************************

    private func validate(authorization: OAuthSwift, for serviceName: String, using testUrl: String, completion: @escaping (Result<OAuthSwiftResponse, OAuthSwiftError>) -> ()) {

        self.log("\(serviceName): Validating authorization using - \(testUrl)")

        _ = authorization.client.get(testUrl) { result in
            switch result {
            case .success: self.log("\(serviceName): Authorization validation succeeded.")
            case .failure(let error): self.log("\(serviceName): Authorization validation failed: \(error.name)")
            }
            completion(result)
        }
    }

    // **********************************************************************************************************************************}
    // OAuth1
    // **********************************************************************************************************************************

    // **********************************************************************************************************************************}
    // OAuth2
    // **********************************************************************************************************************************

    struct OAuth2AuthorizationParameters {
        let consumerKey: String
        let consumerSecret: String
        let authorizeUrl: String
        let accessTokenUrl: String
        let redirectUri: String
        let responseType: String
        let scope: String
        let state: String
    }

    func authorize(serviceName: String, parameters: OAuth2AuthorizationParameters, authorizationTestUrl: String?, completion: @escaping (Bool) -> ()) {

        log("\(serviceName): Authorizing access with Oauth2")

        let authorization = OAuth2Swift(consumerKey: parameters.consumerKey, consumerSecret: parameters.consumerSecret,
                                        authorizeUrl: parameters.authorizeUrl, accessTokenUrl: parameters.accessTokenUrl,
                                        responseType: parameters.responseType)
        authorization.allowMissingStateCheck = true
        authorization.authorizeURLHandler = SafariURLHandler.init(viewController: self, oauthSwift: authorization)

        authorize(serviceName: serviceName, using: authorization, with: parameters.redirectUri, and: authorizationTestUrl,
                  scope: parameters.scope, state: parameters.state, completion: completion)
    }

    private func authorize(serviceName: String, using authorization: OAuth2Swift, with redirectUri: String, and testUrl: String?, scope: String, state: String, completion: @escaping (Bool) -> ()) {

        func authorize() {
            guard let callbackURL = URL(string: redirectUri) else {
                log("\(serviceName): Invalid redirect URI - \(redirectUri)");
                completion(false)
                return
            }

            authorization.authorize(withCallbackURL: callbackURL, scope: scope, state: state) { result in
                switch result {

                case .success(let (credentials, _, _)):
                    self.log("\(serviceName): Authorization succeeded")
                    self.storeCredentials(for: serviceName, credentials)
                    self.authorization = authorization
                    completion(true)

                case .failure(let error):
                    self.log("\(serviceName): Authorization failed - \(error)")
                    completion(false)
                }
            }
        }

        func authorize(with token: String) {
            log("\(serviceName): Authorizing with access token")

            authorization.client.credential.oauthToken = token
            if let tokenSecret = retrieveTokenSecret(for: serviceName) { authorization.client.credential.oauthTokenSecret = tokenSecret }

            guard let testUrl = testUrl else {
                self.authorization = authorization
                completion(true)
                return
            }

            validate(authorization: authorization, for: serviceName, using: testUrl) { result in
                switch result {

                case .success:
                    self.authorization = authorization
                    completion(true)

                case .failure(let error):
                    if case .tokenExpired = error {
                        self.refresh(authorization: authorization, for: serviceName) { credentials in
                            if let credentials = credentials {
                                self.storeCredentials(for: serviceName, credentials)
                                self.authorization = authorization
                                completion(true)
                            }
                            else {
                                authorize()
                            }
                        }
                    }
                    else {
                        authorize()
                    }
                }
            }
        }

        if let token = retrieveToken(for: serviceName) { authorize(with: token) }
        else { authorize() }
    }
    
    private func refresh(authorization: OAuth2Swift, for serviceName: String, completion: @escaping (OAuthSwiftCredential?) -> ()) {

        self.log("\(serviceName): Refreshing authorization")

        guard let refreshToken = retrieveRefreshToken(for: serviceName) else {
            self.log("\(serviceName): Cannot refresh credentials; we do not have a refresh token")
            completion(nil)
            return
        }

        authorization.renewAccessToken(withRefreshToken: refreshToken) { result in
            switch result {

            case .success(let (credentials, _, _)):
                self.log("\(serviceName): The credentials were successfully refreshed.")
                completion(credentials)

            case .failure(let error):
                self.log("\(serviceName): The credentials could not be refreshed - \(error.name)");
                completion(nil)
            }
        }
    }

}
