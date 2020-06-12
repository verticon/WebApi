//
//  TwitterViewController.swift
//  Examples
//
//  Created by Robert Vaessen on 6/4/20.
//  Copyright © 2020 Robert Vaessen. All rights reserved.
//

import UIKit
import OAuthSwift

class TwitterViewController: OAuthViewController {

    private let serviceName = "Twitter"

    private let appName = "VerticonsTwitterApiExplorer"
    private let apiKey = "IsE4XpDiy3nF0XPUTb4NaDiu7"
    private let apiSecretKey = "VEnWO1dTpuIWzqJxFX4rSTukXlHfS6V8o3A3P99QN5PKrp4BlR"
    private let bearerToken = "AAAAAAAAAAAAAAAAAAAAAHCmEwEAAAAA%2BcQ1X4hnziHDb5VpoL8UzLdtDOU%3D4pbi0s0Ow5vBdX9NaiKgBoc1GWqemN5MJCDghD7k3oQ8zEh9Kt"

    //private let accessToken = "1038419485-QWMEVSDp9Au9eSDunV4qohDzGFJ8IBeVeIiN63V"
    //private let accessTokenSecret = "ouFsFKrbNFWa3bFljHDiX75yz1csGZgiFWOB2gDiwIyXg"

    // https://oauthswift.herokuapp.com/callback/some-name will redirect to oauth-swift://oauth-callback/some-name
    // see: https://oauthswift.herokuapp.com and https://github.com/dongri/oauthswift.herokuapp.com
    let redirector = "https://oauthswift.herokuapp.com/callback/twitter"

    override func viewDidLoad() {
        super.viewDidLoad()

        //storeCredentials(serviceName: serviceName, oauthToken: accessToken, oauthTokenSecret: accessTokenSecret, oauthRefreshToken: "")

        doOAuthTwitter()
        //authorize()
    }
    
    private func authorize() {

        let parameters = OAuth2AuthorizationParameters(consumerKey: apiKey, consumerSecret: apiSecretKey,
            authorizeUrl: "https://api.twitter.com/oauth/authorize", accessTokenUrl: "https://api.twitter.com/oauth/access_token",
            redirectUri: redirector, responseType: "", scope: "", state: "")

        authorize(serviceName: serviceName, parameters: parameters, authorizationTestUrl: nil) { (succeeded: Bool) in }
    }

    // *****************************************************************************************************************************************
    //
    // *****************************************************************************************************************************************

    private var oauthswift: OAuth1Swift!
    private var handle: OAuthSwiftRequestHandle!
    private var newOAuthToken: String!

    private func doOAuthTwitter() {
        let oauthswift = OAuth1Swift(
            consumerKey:    apiKey,
            consumerSecret: apiSecretKey,
            requestTokenUrl: "https://api.twitter.com/oauth/request_token",
            authorizeUrl:    "https://api.twitter.com/oauth/authorize",
            accessTokenUrl:  "https://api.twitter.com/oauth/access_token"
        )
        self.oauthswift = oauthswift
        oauthswift.authorizeURLHandler = getURLHandler()

        let _ = oauthswift.authorize(withCallbackURL: URL(string: redirector)!) { result in
            switch result {
            case .success(let (credential, _, _)):
                self.showTokenAlert(credential: credential)
                self.testTwitter(oauthswift)
            case .failure(let error):
                print(error.description)
            }
        }
    }

    private func testTwitter(_ oauthswift: OAuth1Swift) {
        let _ = oauthswift.client.get("https://api.twitter.com/1.1/statuses/mentions_timeline.json", parameters: [:]) { result in
            switch result {
            case .success(let response):
                let jsonDict = try? response.jsonObject()
                print(String(describing: jsonDict))
            case .failure(let error):
                print(error)
            }
        }
    }

    private func getURLHandler() -> OAuthSwiftURLHandlerType {
        let handler = SafariURLHandler(viewController: self, oauthSwift: self.oauthswift!)
        handler.presentCompletion = {
            print("Safari presented")
        }
        handler.dismissCompletion = {
            print("Safari dismissed")
        }
        
        return handler
    }

    private func showAlertView(title: String, message: String) {
        #if os(iOS)
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        #elseif os(OSX)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Close")
        alert.runModal()
        #endif
    }
    
    func showTokenAlert(credential: OAuthSwiftCredential) {
        var message = "oauth_token:\(credential.oauthToken)"
        if !credential.oauthTokenSecret.isEmpty {
            message += "\n\noauth_token_secret:\(credential.oauthTokenSecret)"
        }
        self.showAlertView(title: serviceName, message: message)
    }

    /*
    private func getURLHandler() -> OAuthSwiftURLHandlerType {
        guard let type = self.formData.data?.handlerType else {
            return OAuthSwiftOpenURLExternally.sharedInstance
        }
        switch type {
        case .external :
            return OAuthSwiftOpenURLExternally.sharedInstance
        case .`internal`:
            if internalWebViewController.parent == nil {
                self.addChild(internalWebViewController)
            }
            return internalWebViewController
        case .safari:
            #if os(iOS)
            if #available(iOS 9.0, *) {
                let handler = SafariURLHandler(viewController: self, oauthSwift: self.oauthswift!)
                handler.presentCompletion = {
                    print("Safari presented")
                }
                handler.dismissCompletion = {
                    print("Safari dismissed")
                }
                handler.factory = { url in
                    let controller = SFSafariViewController(url: url)
                    // Customize it, for instance
                    if #available(iOS 10.0, *) {
                        //  controller.preferredBarTintColor = UIColor.red
                    }
                    return controller
                }
                
                return handler
            }
            #endif
            return OAuthSwiftOpenURLExternally.sharedInstance
        case .asWeb:
            #if os(iOS)
            if #available(iOS 13.0, tvOS 13.0, *) {
                return ASWebAuthenticationURLHandler(callbackUrlScheme: "oauth-swift://oauth-callback/", presentationContextProvider: self)
            }
            #endif
            return OAuthSwiftOpenURLExternally.sharedInstance
        }

        #if os(OSX)
        // a better way is
        // - to make this ViewController implement OAuthSwiftURLHandlerType and assigned in oauthswift object
        /* return self */
        // - have an instance of WebViewController here (I) or a segue name to launch (S)
        // - in handle(url)
        //    (I) : affect url to WebViewController, and  self.presentViewControllerAsModalWindow(self.webViewController)
        //    (S) : affect url to a temp variable (ex: urlForWebView), then perform segue
        /* performSegueWithIdentifier("oauthwebview", sender:nil) */
        //         then override prepareForSegue() to affect url to destination controller WebViewController
        
        #endif
    }
 */
}
