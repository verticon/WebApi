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

    // https://oauthswift.herokuapp.com/callback/some-name will redirect to oauth-swift://oauth-callback/some-name
    // see: https://oauthswift.herokuapp.com and https://github.com/dongri/oauthswift.herokuapp.com
    func getRedirector(for serviceName: String) -> String { return "https://oauthswift.herokuapp.com/callback/\(serviceName)" }

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

    struct OAuth1AuthorizationParameters {
        let consumerKey: String
        let consumerSecret: String
        let requestTokenUrl: String
        let authorizeUrl: String
        let accessTokenUrl: String
        let redirectUri: String
    }

    func authorize(serviceName: String, parameters: OAuth1AuthorizationParameters, authorizationTestUrl: String?, completion: @escaping (Bool) -> ()) {

        let authorization = OAuth1Swift(consumerKey: parameters.consumerKey, consumerSecret: parameters.consumerSecret,
                                        requestTokenUrl: parameters.requestTokenUrl, authorizeUrl: parameters.authorizeUrl,
                                        accessTokenUrl: parameters.accessTokenUrl)
        authorization.authorizeURLHandler = SafariURLHandler.init(viewController: self, oauthSwift: authorization)

        authorize(serviceName: serviceName, using: authorization, with: parameters.redirectUri, and: authorizationTestUrl, completion: completion)
    }

    private func authorize(serviceName: String, using authorization: OAuth1Swift, with redirectUri: String, and testUrl: String?, completion: @escaping (Bool) -> ()) {

        func authorize() {
            log("\(serviceName): Acquiring access token")

            guard let callbackURL = URL(string: redirectUri) else {
                 log("\(serviceName): Invalid redirect URI - \(redirectUri)");
                 completion(false)
                 return
             }

            _ = authorization.authorize(withCallbackURL: callbackURL) { result in
               switch result {
               case .success(let (credentials, _, _)):
                   self.log("\(serviceName): Authorization succeeded")
                   self.storeCredentials(for: serviceName, credentials)
                   self.authorization = authorization
                   completion(true)
               case .failure(let error):
                self.log("\(serviceName): Authorization failed - \(error.description)")
               }
            }
        }

        func authorize(with token: String) {
            log("\(serviceName): Authorizing with stored access token")

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

                case .failure:
                    authorize()
                }
            }
        }

        log("\(serviceName): Authorizing access with Oauth1")

        if let token = retrieveToken(for: serviceName) { authorize(with: token) }
        else { authorize() }
    }

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
            log("\(serviceName): Acquiring access token")

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
            log("\(serviceName): Authorizing with stored access token")

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

        log("\(serviceName): Authorizing access with Oauth2")

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
