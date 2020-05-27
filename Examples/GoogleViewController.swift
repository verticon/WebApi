//
//  GoogleViewController.swift
//  WebApi
//
//  Created by Robert Vaessen on 9/18/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit
import OAuthSwift

class GoogleViewController: ApiViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var uploadButton: UIButton!

    private var authorization: OAuth2Swift?
    private var parameters: [String : Any]?

    private var images = [UIImage]()
    private let imageViewCellReuseIdentifier = "ImageViewCell"
    @IBOutlet weak var imageCollection: UICollectionView!


    override func viewDidLoad() {
        super.viewDidLoad()

        let imageViewCellNib = UINib(nibName: "ImageViewCell", bundle: nil)
        imageCollection.register(imageViewCellNib, forCellWithReuseIdentifier: imageViewCellReuseIdentifier)

        authorize()
    }

    private func authorize() {
        log("Authorizing access to google drive")

        let authorization = OAuth2Swift(
            // 555550332418-36mf5bhk6d2j654toraovg2ef9h5simv.apps.googleusercontent.com
            consumerKey:    "555550332418-41183s354gf2faro1qng7nkm7pl4pvqt.apps.googleusercontent.com",
            consumerSecret: "", // No secret required
            authorizeUrl:   "https://accounts.google.com/o/oauth2/auth",
            accessTokenUrl: "https://accounts.google.com/o/oauth2/token",
            responseType:   "code")
        authorization.allowMissingStateCheck = true
        authorization.authorizeURLHandler = SafariURLHandler(viewController: self, oauthSwift: authorization)
        
        // Google API setup for iOS wants the app's bundle ID.
        // It then expects the redirect URL's scheme to match it. WTF?
        let endPoint = "com.rvaessen.WebApi:/oauth2redirect/google"
        guard let callbackURL = URL(string: endPoint) else { log("Could not create URL from \(endPoint)"); return }
        
        authorization.authorize(withCallbackURL: callbackURL, scope: "https://www.googleapis.com/auth/drive", state: "") { result in
            switch result {

            case .success(let (credential, response, parameters)):
                self.log("Authorization to access the google drive was granted.\n\tCredential = \(credential)\n\tresponse = \(String(describing: response))\n\tParameters = \(parameters)")

                self.authorization = authorization
                self.parameters = parameters
                self.uploadButton.isEnabled = true

                self.downloadImages { image in
                    DispatchQueue.main.async {
                        self.images.append(image)
                        self.imageCollection.reloadData()
                    }
                }

            case .failure(let error):
                self.log("Authorization to access the google drive was denied: \(error)")
            }
        }
    }

    // ******************************************************************************************************

    @IBAction func upload(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
            imagePicker.allowsEditing = false
            present(imagePicker, animated: true, completion: nil)
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        picker.dismiss(animated: true, completion: nil)

        guard let image = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage, let data = image.jpegData(compressionQuality: 0.75)
        else { log("Cannot obtain image"); return }

        uploadButton.isEnabled = false
        upload(image: data) { error in
            self.log("The image \((error == nil) ? "was successfully uploaded" : "could not be uploaded: \(error!)")")
            DispatchQueue.main.async { self.uploadButton.isEnabled = true }
        }
    }

    private func upload(image: Data, completion: @escaping (Error?) -> ()) {
        guard let authorization = authorization, let parameters = parameters else { return }

        authorization.client.postImage("https://www.googleapis.com/upload/drive/v2/files", parameters: parameters, image: image) { result in
            switch result {

            case .success: completion(nil)

            case .failure(let error): completion(error)
            }
        }
    }

    // ******************************************************************************************************

    private func downloadImages(handler: @escaping (UIImage) -> ()) {
        guard let authorization = authorization, let parameters = parameters else { return }

        func downloadFiles(response: OAuthSwiftResponse) {
            do {

                struct FileList : Codable {
                    struct File : Codable {
                        let mimeType: String
                        let thumbnailLink: String
                    }

                    let items: [File]
                }

                let fileList = try JSONDecoder().decode(FileList.self, from: response.data)

                for file in fileList.items {
                    guard file.mimeType.starts(with: "image") else { continue }

                    _ = authorization.client.get(file.thumbnailLink, parameters: parameters) { result in
                        switch result {

                        case .success(let response):
                            if let image = UIImage(data: response.data) { handler(image) }
                            else { self.log("A UIImage could not be created from the thumbnail response data") }

                        case .failure(let error):
                            self.log("The thumbnail could not be downloaded: \(error.localizedDescription)")
                        }
                    }
                }
            }
            catch { self.log("Could not decode response data to obtain file list info: \(error)") }
        }

        _ = authorization.client.get("https://www.googleapis.com/drive/v2/files", parameters: parameters) { result in
            switch result {

            case .success(let response): downloadFiles(response: response)

            case .failure(let error): self.log("The files could not be downloaded: \(error.localizedDescription)")
            }
        }
    }
}

extension GoogleViewController : UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: imageViewCellReuseIdentifier, for: indexPath) as! ImageViewCell
        cell.imageView.image = images[indexPath.item]
        return cell
    }
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
