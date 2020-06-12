//
//  ViewController.swift
//  JsonPlaceHolder
//
//  Created by Robert Vaessen on 9/16/18.
//  Copyright © 2018 Robert Vaessen. All rights reserved.
//

import UIKit

class GeneralViewController: ApiViewController {
    
    // Examples
    //  Get
    //      https://jsonplaceholder.typicode.com/users
    //      https://jsonplaceholder.typicode.com/users/1

    @IBOutlet weak var endPointTextField: UITextField!
    private var endPoint: String { return endPointTextField.text ?? "" }

    override func viewDidLoad() {
        super.viewDidLoad()

        endPointTextField.attributedPlaceholder =
            NSAttributedString(string: "Enter an endpoint url", attributes: [NSAttributedString.Key.foregroundColor : UIColor.white])
    }

    @IBAction func get(_ sender: UIButton) {
        endPointTextField.endEditing(true)
        get(endPoint: endPoint)
    }

    @IBAction func unwind(_ unwindSegue: UIStoryboardSegue) {
        guard let vc = unwindSegue.source as? PostDataViewController else { return }
        post(jsonText: vc.postData.text, to: endPoint)
    }

    @IBAction func _delete(_ sender: UIButton) {
        endPointTextField.endEditing(true)
        delete(endPoint: endPoint)
    }
}

