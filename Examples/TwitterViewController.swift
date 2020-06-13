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

    private let testUrl = "https://api.twitter.com/1.1/statuses/mentions_timeline.json"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        authorize() { status in
            guard status else { return }

            _ = self.authorization!.client.get(self.testUrl, parameters: [:]) { result in
                switch result {
                case .success(let response):
                    let jsonDict = try? response.jsonObject()
                    self.log(String(describing: jsonDict))
                case .failure(let error):
                    self.log(error.description)
                }
            }
        }
    }
    
    private func authorize(completion: @escaping (Bool) -> ()) {

        let parameters = OAuth1AuthorizationParameters(consumerKey: apiKey, consumerSecret: apiSecretKey,
            requestTokenUrl: "https://api.twitter.com/oauth/request_token",  authorizeUrl: "https://api.twitter.com/oauth/authorize",
            accessTokenUrl: "https://api.twitter.com/oauth/access_token", redirectUri: getRedirector(for: serviceName.lowercased()))

        authorize(serviceName: serviceName, parameters: parameters, authorizationTestUrl: testUrl, completion: completion)
    }
}
