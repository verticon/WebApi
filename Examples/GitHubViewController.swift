//
//  GitHubViewController.swift
//  WebApi
//
//  Created by Robert Vaessen on 9/17/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit
import OAuthSwift

class GitHubViewController: ApiViewController {

    @IBOutlet weak var createButton: UIButton!

    private let personalToken = "abdab236972b6515fc36015fe0e1bfbe11e2c1ad"
    private var authorization: OAuth2Swift?
    private var parameters: [String : Any]?

    @IBOutlet weak var repoName: UITextField!

    override func viewDidLoad() {
        authorize()

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(endEditting))
        view.addGestureRecognizer(tapRecognizer)
    }

    @IBAction func createRepo(_ sender: UIButton) {
        guard let name = repoName.text, name.count > 0 else { log("Please provide a repo name"); return }
        
        let endPoint = "https://api.github.com/user/repos"
        let description = "A test repository for exercising the github web api"

        func create1() {
            struct CreateRepoData : Codable {
                let name: String
                let description: String
            }
            let createRepoData = CreateRepoData(name: name, description: description)

            do {
                let data = try JSONEncoder().encode(createRepoData)
                post(jsonData: data, to: endPoint, with: personalToken)
            }
            catch { log("Cannot encode the create repo data: \(error)") }
        }
        
        func create2() {
            guard let authorization = authorization else { return }
            
            _ = authorization.client.post(endPoint, parameters: ["name" : name, "desription" : description], headers: ["content-type":"application/json"]) { result in
                switch result {

                case .success(let response):
                    self.log("The \(name) repo was successfully created: \(response)")

                case .failure(let error):
                    self.log("The \(name) repo could not be created: \(error.localizedDescription)")
                }
            }
        }
        
        create2()

        repoName.endEditing(true)
    }

    @objc private func endEditting(_ recognizer: UITapGestureRecognizer) {
        repoName.endEditing(true)
    }

    private func authorize() {
        self.log("Authorizing access to github")

        let authorization = OAuth2Swift(consumerKey: "7a68e2f2670f13dae4c4", consumerSecret: "822e869d88e2c801ae59bd04e4262cdfe453414e",
            authorizeUrl: "http://github.com/login/oauth/authorize", accessTokenUrl: "https://github.com/login/oauth/access_token", responseType: "code")

        authorization.allowMissingStateCheck = true
        authorization.authorizeURLHandler = SafariURLHandler(viewController: self, oauthSwift: authorization)
        
        let endPoint = "github://com.rvaessen.webapi:/oauth2Callback"
        guard let callbackURL = URL(string: endPoint) else { log("Could not create URL from \(endPoint)"); return }
        
        authorization.authorize(withCallbackURL: callbackURL, scope: "repo", state: "") { result in
            switch result {

            case .success(let (credential, response, parameters)):
                self.log("Authorization to access GitHub was granted.\n\tCredential = \(credential)\n\tresponse = \(String(describing: response))\n\tParameters = \(parameters)")
                self.authorization = authorization
                self.parameters = parameters
                self.createButton.isEnabled = true

            case .failure(let error):
                self.log("Authorization to access GitHub was denied: \(error)");
            }
        }
    }
}
