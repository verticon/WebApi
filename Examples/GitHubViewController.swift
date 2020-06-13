//
//  GitHubViewController.swift
//  WebApi
//
//  Created by Robert Vaessen on 9/17/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit
import OAuthSwift

class GitHubViewController: OAuthViewController {

    @IBOutlet weak var repoName: UITextField!
    @IBOutlet weak var createButton: UIButton!

    private let serviceName = "GitHub"
    private let endPoint = "https://api.github.com/user/repos"

    override func viewDidLoad() {
        super.viewDidLoad()

        authorize()

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(endEditting))
        view.addGestureRecognizer(tapRecognizer)
    }

    private func authorize() {

        let parameters = OAuth2AuthorizationParameters(consumerKey: "7a68e2f2670f13dae4c4",
            consumerSecret: "822e869d88e2c801ae59bd04e4262cdfe453414e", authorizeUrl: "http://github.com/login/oauth/authorize",
            accessTokenUrl: "https://github.com/login/oauth/access_token", redirectUri: "oauth-swift://oauth-callback/\(serviceName.lowercased())",
            responseType: "code", scope: "repo", state: "")

        authorize(serviceName: serviceName, parameters: parameters, authorizationTestUrl: "https://api.github.com/user") { (succeeded: Bool) in
            if succeeded { self.queryRepos() }
        }
    }

    private func queryRepos() {
        if let authorization = authorization {
            log("Querying GitHub repos using OAuth2")

            _ = authorization.client.get(endPoint) { result in
                switch result {
                case .success(let response):
                    self.log("The query succeeded")
                    do {
                        let json = try JSONSerialization.jsonObject(with: response.data, options: [])
                        guard let array = json as? JSONArray else { self.log("Json is not array"); return }
                        let repoList = array.map { $0 as! JSONDictionary }
                        self.log("There are \(repoList.count) repositories:")
                        for repo in repoList { self.log("\n\t\(repo["name"] ?? "<no name>" as AnyObject) - \(repo["description"] ?? "<no description>" as AnyObject)") }
                    }
                    catch { self.log("Cannot convert json data to object: \(error)")}

                case .failure(let error):
                    self.log("The query failed: \(error.name)")
                }
            }
        }
    }

    @IBAction func createRepo(_ sender: UIButton) {
        guard let name = repoName.text, name.count > 0 else { log("Please provide a repo name"); return }
        let description = "A test repository for exercising the github web api"

        if let authorization = authorization {
            log("Creating GitHub repo \(name) using OAuth2")

            let parameters = ["name" : name, "desription" : description]
            let headers = ["content-type":"application/json"]

            _ = authorization.client.post(endPoint, parameters: parameters, headers: headers) { result in
                switch result {

                case .success:
                    self.log("The \(name) repo was successfully created.")

                case .failure(let error):
                    self.log("The \(name) repo could not be created: \(error.name)")
                }
            }
        }
        else {
            log("Creating GitHub repo \(name) using personal token")
    
            let personalToken = "abdab236972b6515fc36015fe0e1bfbe11e2c1ad"

            struct Parameters : Codable {
                let name: String
                let description: String
            }
            let parameters = Parameters(name: name, description: description)

            do {
                let data = try JSONEncoder().encode(parameters)
                post(jsonData: data, to: endPoint, with: personalToken)
            }
            catch {
                log("Cannot encode the create repo parameters: \(error)")
            }
        }

        repoName.endEditing(true)
    }

    @objc private func endEditting(_ recognizer: UITapGestureRecognizer) {
        repoName.endEditing(true)
    }
}
