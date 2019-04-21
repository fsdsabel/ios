//
//  NCViewerMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/09/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//

import Foundation
import KTVHTTPCache
import SRGMediaPlayer

class NCViewerMedia: NSObject {

    var detail: CCDetail!
    var metadata: tableMetadata!
    var videoURL: URL!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: Int = 0
    var previousButton: UIBarButtonItem!
    var nextButton: UIBarButtonItem!
    var playerController: SRGMediaPlayerViewController!

    @objc static let sharedInstance: NCViewerMedia = {
        let viewMedia = NCViewerMedia()
        viewMedia.setupHTTPCache()
        return viewMedia
    }()

    @objc func viewMedia(_ metadata: tableMetadata, detail: CCDetail) {
        
        
        self.detail = detail
        
        
        guard let rootView = UIApplication.shared.keyWindow else {
            return
        }
        
        if #available(iOS 11.0, *) {
            safeAreaBottom = Int(rootView.safeAreaInsets.bottom)
        }
        
        guard let videoURLProxy = loadMetadata(metadata: metadata) else {
            return
        }
        
        playerController = SRGMediaPlayerViewController()
        appDelegate.playerController = playerController
        
        playerController.controller.playerCreationBlock = { (player) -> Void in
             player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        }
        
        playerController.view.frame = CGRect(x: 0, y: 0, width: Int(detail.view.bounds.size.width), height: Int(detail.view.bounds.size.height) - Int(k_detail_Toolbar_Height) - safeAreaBottom - 1)
        detail.addChild(playerController)
        detail.view.addSubview(playerController.view)
        playerController.didMove(toParent: detail)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.SRGMediaPlayerPlaybackStateDidChange, object: playerController.controller, queue: nil) { (notification) in
            switch(self.playerController.controller.playbackState) {
            case .ended:
                self.currentMediaIndex += 1
                break
            default:
                break
            }
            
        }
        
        
      //  SRGMediaPlayerViewController
        /*appDelegate.player = AVPlayer(url: videoURLProxy)
        appDelegate.playerController = AVPlayerViewController()
        
        appDelegate.playerController.player = appDelegate.player
        appDelegate.playerController.view.frame = CGRect(x: 0, y: 0, width: Int(detail.view.bounds.size.width), height: Int(detail.view.bounds.size.height) - Int(k_detail_Toolbar_Height) - safeAreaBottom - 1)
        appDelegate.playerController.allowsPictureInPicturePlayback = false
        detail.addChild(appDelegate.playerController)
        detail.view.addSubview(appDelegate.playerController.view)
        appDelegate.playerController.didMove(toParent: detail)
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: nil) { (notification) in
            let player = notification.object as! AVPlayerItem
            player.seek(to: CMTime.zero)
        }
        
        appDelegate.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)*/
        
        
        detail.isMediaObserver = true
        
        augmentToolbar()
        
        //appDelegate.player.play()
        playerController.controller.play(videoURLProxy)
    }
    
    private func augmentToolbar() {
        let fixedSpaceMini = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.fixedSpace, target: self, action: nil)
        fixedSpaceMini.width = 25
        previousButton = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "previous"), width: 28, height: 34, color:NCBrandColor.sharedInstance.icon), style: UIBarButtonItem.Style.plain, target:self, action:#selector(NCViewerMedia.previousButtonPressed(button:)))
        nextButton = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "next"), width: 28, height: 34, color:NCBrandColor.sharedInstance.icon), style: UIBarButtonItem.Style.plain, target:self, action:#selector(NCViewerMedia.nextButtonPressed(button:)))
        
        updateStates()
        
        var items = detail.toolbar.items
        items?.insert(nextButton, at: 0);
        items?.insert(fixedSpaceMini, at: 0);
        items?.insert(previousButton, at: 0);
        detail.toolbar.setItems(items, animated: false)
    }
    
    private func getUrl(metadata: tableMetadata) -> (url:URL, proxyUrl: URL, isLocal: Bool)? {
        if CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
            
            let videoURL = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView))
            return (videoURL, videoURL, true)
            
        }
        guard let stringURL = (metadata.serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        let videoURL = URL(string: stringURL)
        let videoURLProxy = KTVHTTPCache.proxyURL(withOriginalURL: self.videoURL)
        
        guard let authData = (appDelegate.activeUser + ":" + appDelegate.activePassword).data(using: .utf8) else {
            return nil
        }
        
        let authValue = "Basic " + authData.base64EncodedString(options: [])
        KTVHTTPCache.downloadSetAdditionalHeaders(["Authorization":authValue, "User-Agent":CCUtility.getUserAgent()])
        
        return (videoURL!, videoURLProxy!, false)
    }
    
    private func loadMetadata(metadata: tableMetadata) -> URL? {
        self.metadata = metadata
        let urlData = getUrl(metadata: metadata)
        if urlData == nil {
            return nil
        }
        self.videoURL = urlData!.url
        let videoURLProxy = urlData!.proxyUrl
        if !urlData!.isLocal {
            // Disable Button Action (the file is in download via Proxy Server)
            detail.buttonAction.isEnabled = false
        }
        return videoURLProxy
    }
    
    @objc func previousButtonPressed(button:UIBarButtonItem) {
        currentMediaIndex -= 1
    }
    
    @objc func nextButtonPressed(button:UIBarButtonItem) {
        currentMediaIndex += 1
    }
    
    
    var currentMediaIndex: Int {
        get {
            return detail.medias.index(of: metadata)
        }
        set (value) {
            let currentIndex = currentMediaIndex
            
            if value == currentIndex {
                return
            }
            let newIndex = value % detail.medias.count
            metadata = detail.medias.object(at: newIndex) as? tableMetadata
            
            guard let url = loadMetadata(metadata: metadata) else {
                return
            }
            detail.navigationController?.navigationBar.topItem?.title = metadata.fileNameView
            detail.metadataDetail = metadata
            playerController.controller.play(url)
            updateStates()
        }
    }
    
    func updateStates() {
        previousButton.isEnabled = currentMediaIndex > 0
        nextButton.isEnabled = currentMediaIndex < detail.medias.count - 1
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        //TODO: call that
        if keyPath != nil && keyPath == "rate" {
            
            if appDelegate.playerController.controller.player?.rate == 1 {
                print("start")
            } else {
                print("stop")
            }
            
            // Save cache
            if !CCUtility.fileProviderStorageExists(self.metadata.fileID, fileNameView:self.metadata.fileNameView) {
                
                guard let url = KTVHTTPCache.cacheCompleteFileURL(with: self.videoURL) else {
                    return
                }
                
                CCUtility.copyFile(atPath: url.path, toPath: CCUtility.getDirectoryProviderStorageFileID(self.metadata.fileID, fileNameView: self.metadata.fileNameView))
                NCManageDatabase.sharedInstance.addLocalFile(metadata: self.metadata)
                KTVHTTPCache.cacheDelete(with: self.videoURL)
                
                // reload Data Source
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl:self.metadata.serverUrl, fileID: self.metadata.fileID, action: k_action_MOD)
                
                // Enabled Button Action (the file is in local)
                self.detail.buttonAction.isEnabled = true
            }
        }
    }
    
    @objc func removeObserver() {
        
       // appDelegate.player.removeObserver(self, forKeyPath: "rate", context: nil)
       // NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        appDelegate.playerController?.controller.player?.removeObserver(self, forKeyPath: "rate", context: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.SRGMediaPlayerPlaybackStateDidChange, object: playerController.controller)
    }
    
    @objc func setupHTTPCache() {
        
        KTVHTTPCache.cacheSetMaxCacheLength(Int64(k_maxHTTPCache))
        
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            KTVHTTPCache.logSetConsoleLogEnable(true)
        }
        
        do {
            try KTVHTTPCache.proxyStart()
        } catch let error {
            print("Proxy Start error : \(error)")
        }
        
        KTVHTTPCache.encodeSetURLConverter { (url) -> URL? in
            print("URL Filter reviced URL : " + String(describing: url))
            return url
        }
        
        KTVHTTPCache.downloadSetUnacceptableContentTypeDisposer { (url, contentType) -> Bool in
            print("Unsupport Content-Type Filter reviced URL : " + String(describing: url) + " " + String(describing: contentType))
            return false
        }
    }
}
