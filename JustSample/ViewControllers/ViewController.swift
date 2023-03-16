//
//  ViewController.swift
//  JustSample
//
//  Created by UMCios on 2023/03/13.
//

import UIKit
import Photos
import MLKit

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var resultsLabel: UILabel!
    
    let textRecognizer = TextRecognizer.textRecognizer()
    
    /// A string holding current results from detection.
    var resultsText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func pickImage(_ sender: Any) {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            presentImagePicker()
        } else if status == .denied {
            showAccessDeniedAlert()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async { [weak self] in
                    if status == .authorized {
                        self?.presentImagePicker()
                    } else {
                        self?.showAccessDeniedAlert()
                    }
                }
            }
        }
    }
    
    //MARK: - Private
    private func presentImagePicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    
    private func showAccessDeniedAlert() {
        let alert = UIAlertController(title: "Access Denied", message: "Please allow access to your photo library in the Settings app.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        present(alert, animated: true)
    }
}


// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.originalImage] as? UIImage {
            imageView.image = selectedImage

            let visionImage = VisionImage(image: selectedImage)
            textRecognizer.process(visionImage) { result, error in
                guard error == nil, let result = result else {
                    print("Error: \(error?.localizedDescription ?? "Unknown error.")")
                    return
                }
                
                // Process the recognized text
                var resultsText = ""
                for block in result.blocks {
                    for line in block.lines {
                        for element in line.elements {
                            resultsText += "\(element.text) "
                        }
                        resultsText += "\n"
                    }
                    resultsText += "\n" 
                }
                self.resultsText = resultsText
                self.resultsLabel.text = self.resultsText
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension UIImage {
    
    //NOTE: This is not thread safe, please run it on a background thread.
    convenience init?(fromFile filePath:String) {
        guard let url = URL(string: filePath) else {
            return nil
        }
        
        self.init(fromURL: url)
    }
    
    //NOTE: This is not thread safe, please run it on a background thread.
    convenience init?(fromURL url:URL) {
        let imageData: Data
        
        do {
            imageData = try Data(contentsOf: url)
        } catch {
            return nil
        }
        
        self.init(data: imageData)
    }
}
