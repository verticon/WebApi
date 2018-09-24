//
//  ApiViewController.swift
//  WebApi
//
//  Created by Robert Vaessen on 9/18/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit

class ApiViewController: UIViewController {
    
    @IBOutlet weak var console: UITextView!
    @IBAction func clear(_ sender: UIButton) {  console?.text = "" }
    func log(_ text: String, _ newline: Bool = true) {
        guard let console = console else { print(text); return }
        DispatchQueue.main.async { console.text = (console.text ?? "") + text + (newline ? "\n" : "") }
    }

    func getRequest(for endPoint: String) -> URLRequest? {
        guard let url = URL(string: endPoint) else {
            log("Cannot create URL from \"\(endPoint)\"")
            return nil
        }
        return URLRequest(url: url)
    }
    
    func get(endPoint: String) {
        guard let request = getRequest(for: endPoint) else { return }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else { self.log("An error occurred getting data from \(endPoint): \(error!)"); return }
            guard let data = data else { self.log("No data was received from \(endPoint)"); return }
            guard let response = response as? HTTPURLResponse else { self.log("An http response was not received from \(endPoint)"); return }
            
            if self.validate(httpStatus: response.statusCode) {
                do { _ = try JSONSerialization.jsonObject(with: data, options: []) }
                catch { self.log("Cannot convert json data to object: \(error)")}
                
                self.log(String(data: data, encoding: .utf8) ?? "Cannot convert json data to string")
            }
        }
        task.resume()
    }
    
    func delete(endPoint: String) {
        guard var request = getRequest(for: endPoint) else { return }
        request.httpMethod = "DELETE"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else { self.log("An error occurred posting data to \(endPoint): \(error!)"); return }
            guard let response = response as? HTTPURLResponse else { self.log("An http response was not received from \(endPoint)"); return }
            
            if self.validate(httpStatus: response.statusCode) {
                self.log("Successfully deleted \(endPoint); http response code = \(response.statusCode)")
            }
        }
        task.resume()
    }
    
    func post(jsonText: String, to endPoint: String) {

        func jsonTextToObject(_ text: String) -> Any? {
            if let data = text.data(using: .utf8) {
                do { return try JSONSerialization.jsonObject(with: data) }
                catch { log("Cannot convert data to json object: \(error)")}
            }
            else { log("Cannot convert string to data: \(text)") }
            return nil
        }

        do {
            guard let jsonObject = jsonTextToObject(jsonText) else { return }
            let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            post(jsonData: data, to: endPoint)
        }
        catch { log("Cannot convert json object to data: \(error)") }

    }

    func post(jsonData: Data, to endPoint: String, with token: String? = nil) {
        guard var request = getRequest(for: endPoint) else { return }
        request.httpMethod = "POST"

        request.allHTTPHeaderFields = ["content-type" : "application/json"]
        if let token = token { request.allHTTPHeaderFields!["Authorization"] = "token " + token }
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else { self.log("An error occurred posting data to \(endPoint): \(error!)"); return }
            guard let response = response as? HTTPURLResponse else { self.log("An http response was not received from \(endPoint)"); return }
            
            if self.validate(httpStatus: response.statusCode) {
                self.log("Successfully posted to \(endPoint); http response code = \(response.statusCode)")
            }
        }
        task.resume()
    }
    
    func validate(httpStatus: Int) -> Bool {
        guard let status = HttpStatusCode(rawValue: httpStatus) else {
            self.log("\(httpStatus) is not a valid http status code.")
            return false
        }
        
        if status.isSuccess{ return true }
        
        self.log("An http error code was returned: \(status)")
        return false
    }
}
