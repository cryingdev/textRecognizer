//
//  PlayVideoViewController.swift
//  JustSample
//
//  Created by UMCios on 2023/03/10.
//
import UIKit
import AVFoundation

class PlayVideoViewController: UIViewController {

    private let player: AVPlayer
    private let playerLayer: AVPlayerLayer
    private var thumbnailImageView: UIImageView?
    private var images: [UIImage] = []

    init(videoURL: URL) {
        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)

        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        view.backgroundColor = .clear
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)

        // Get the thumbnail at the 5 second mark
        let time = CMTime(seconds: 5, preferredTimescale: 1)
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            self.thumbnailImageView?.image = UIImage(cgImage: imageRef)
            // Do something with the thumbnailImage
            
        } catch let error {
            print("Error generating thumbnail: \(error.localizedDescription)")
        }
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)

        player.play()

        // Create a close button with a system image
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.frame = CGRect(x: view.bounds.width - 80, y: 20, width: 60, height: 40)
        view.addSubview(closeButton)
        
        let remotePanel = UIView()
        remotePanel.backgroundColor = UIColor(white: 0, alpha: 0.5)
        remotePanel.frame = CGRect(x: 0, y: view.bounds.height - 120, width: view.bounds.width, height: 120)
        view.addSubview(remotePanel)
        
        thumbnailImageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 50, height: 50)))
        remotePanel.addSubview(thumbnailImageView!)
        
        let playButton = UIButton(type: .system)
        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playButton.setImage(UIImage(systemName: "play.fill"), for: .selected)
        playButton.tintColor = .white
        playButton.frame = CGRect(x: remotePanel.bounds.width / 2 - 25, y: 55, width: 50, height: 50)
        playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)
        remotePanel.addSubview(playButton)
    }
    

    @objc func playButtonPressed(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        // Start or stop recording depending on button state
        if sender.isSelected {
            player.play()
        } else {
            player.pause()
        }
    }

    @objc private func closeButtonTapped() {
        player.pause()
        dismiss(animated: true, completion: nil)
    }
}
