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

        self.log("Authorizing access to google drive")
        authorize { authorization, parameters, error in
            guard error == nil else {
                self.log("Authorization to access the google drive was denied: \(error!)")
                return
            }

            guard let parameters = parameters else {
                self.log("The authorization parameters are nil???)")
                return
            }
            
            self.log("Authorization to access the google drive was granted.")

            self.authorization = authorization
            self.parameters = parameters
            self.uploadButton.isEnabled = true
            
            self.downloadImages { image in
                DispatchQueue.main.async {
                    self.images.append(image)
                    self.imageCollection.reloadData()
                }
            }
        }
    }

    private func authorize(completion: @escaping (OAuth2Swift, [String : Any]?, Error?) -> Void) {

        let authorization = OAuth2Swift(
            consumerKey:    "555550332418-41183s354gf2faro1qng7nkm7pl4pvqt.apps.googleusercontent.com",
            consumerSecret: "", // No secret required
            authorizeUrl:   "https://accounts.google.com/o/oauth2/auth",
            accessTokenUrl: "https://accounts.google.com/o/oauth2/token",
            responseType:   "code")
        authorization.allowMissingStateCheck = true
        authorization.authorizeURLHandler = SafariURLHandler(viewController: self, oauthSwift: authorization)
        
        let endPoint = "com.rvaessen.WebApi:/oauth2Callback"
        guard let callbackURL = URL(string: endPoint) else { log("Could not create URL from \(endPoint)"); return }
        
        authorization.authorize(withCallbackURL: callbackURL, scope: "https://www.googleapis.com/auth/drive", state: "",
                                success: { credential, response, parameters in completion(authorization, parameters, nil) },
                                failure: { error in completion(authorization, nil, error) }
        )
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
// Local variable inserted by Swift 4.2 migrator.
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

        authorization.client.postImage("https://www.googleapis.com/upload/drive/v2/files", parameters: parameters, image: image,
            success: { response in completion(nil) }, failure: { error in completion(error)
        })
    }

    // ******************************************************************************************************

    private func downloadImages(handler: @escaping (UIImage) -> ()) {
        guard let authorization = authorization, let parameters = parameters else { return }

        let getFilesSuccessCallback = { (response: OAuthSwiftResponse) in
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
                    
                    let getThumbnailSuccessCallback = { (response: OAuthSwiftResponse) in
                        if let image = UIImage(data: response.data) { handler(image) }
                        else { self.log("A UIImage could not be created from the thumbnail response data") }
                    }
                    
                    let getThumbnailFailureCallback = { (error: Error) in
                        self.log("The thumbnail could not be downloaded: \(error.localizedDescription)")
                    }
                    
                    _ = authorization.client.get(file.thumbnailLink, parameters: parameters, success: getThumbnailSuccessCallback, failure: getThumbnailFailureCallback)
                }
            }
            catch { self.log("Could not decode response data to obtain file list info: \(error)") }
        }

        let getFilesFailureCallback = { (error: Error) in
            self.log("The files could not be downloaded: \(error.localizedDescription)")
        }

        _ = authorization.client.get("https://www.googleapis.com/drive/v2/files", parameters: parameters, success: getFilesSuccessCallback, failure: getFilesFailureCallback)
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
