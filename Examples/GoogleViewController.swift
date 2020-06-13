//
//  GoogleViewController.swift
//  WebApi
//
//  Created by Robert Vaessen on 9/18/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//
// https://drive.google.com/drive/my-drive

import UIKit
import OAuthSwift

class GoogleViewController: OAuthViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var uploadButton: UIButton!

    private let serviceName = "GoogleDrive"
    private let fileListUrl = "https://www.googleapis.com/drive/v2/files"

    private var images = [UIImage]()
    private let imageViewCellReuseIdentifier = "ImageViewCell"
    @IBOutlet weak var imageCollection: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let imageViewCellNib = UINib(nibName: "ImageViewCell", bundle: nil)
        imageCollection.register(imageViewCellNib, forCellWithReuseIdentifier: imageViewCellReuseIdentifier)

        authorize() { status in
            guard status else { return }

            self.downloadImages { image in
                DispatchQueue.main.async {
                    self.images.append(image)
                    self.imageCollection.reloadData()
                }
            }
        }
    }

    private func authorize(completion: @escaping (Bool) -> ()) {

        // When setting up an iOS app in the Google developer's console, the app's  bundle id must be entered.
        // Apparently Google requires that the redirect URL's schem match the bundle ID. Huh?
        let parameters = OAuth2AuthorizationParameters(consumerKey: "555550332418-41183s354gf2faro1qng7nkm7pl4pvqt.apps.googleusercontent.com",
            consumerSecret: "", authorizeUrl: "https://accounts.google.com/o/oauth2/auth",
            accessTokenUrl: "https://accounts.google.com/o/oauth2/token", redirectUri: "com.rvaessen.WebApi:/oauth2redirect/google",
            responseType: "code", scope: "https://www.googleapis.com/auth/drive", state: "")
 
        authorize(serviceName: serviceName, parameters: parameters, authorizationTestUrl: fileListUrl, completion: completion)
    }

    // ******************************************************************************************************
    // Upload
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
        guard let authorization = authorization else { return }

        authorization.client.postImage("https://www.googleapis.com/upload/drive/v2/files", parameters: Dictionary<String, Any>(), image: image) { result in
            switch result {

            case .success: completion(nil)

            case .failure(let error): completion(error)
            }
        }
    }

    // ******************************************************************************************************
    // Download
    // ******************************************************************************************************

    private func downloadImages(handler: @escaping (UIImage) -> ()) {
        guard let authorization = authorization else { return }

        func downloadThumbnails(response: OAuthSwiftResponse) {
            do {

                struct FileList : Codable {
                    struct File : Codable {
                        let mimeType: String
                        let thumbnailLink: String
                    }

                    let items: [File]
                }

                let fileList = try JSONDecoder().decode(FileList.self, from: response.data)
                let imageList = fileList.items.filter() { file in file.mimeType.starts(with: "image") }
                log("GoogleDrive: Downloading \(imageList.count) image thumbnails")
                for image in imageList {
                    _ = authorization.client.get(image.thumbnailLink) { result in
                        switch result {

                        case .success(let response):
                            if let image = UIImage(data: response.data) { handler(image) }
                            else { self.log("A UIImage could not be created from the thumbnail response data") }

                        case .failure(let error):
                            self.log("The thumbnail could not be downloaded:  \(error.name)")
                        }
                    }
                }
            }
            catch { self.log("Could not decode response data to obtain file list info: \(error)") }
        }

        log("GoogleDrive: Obtaining list of files")
        _ = authorization.client.get(fileListUrl) { result in
            switch result {

            case .success(let response): downloadThumbnails(response: response)

            case .failure(let error): self.log("GoogleDrive: The file list could not be obtained: \(error.name)")
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
