//
//  InterfaceController.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import Locksmith
import WebUntis

let okButton = WKAlertAction.init(title: "Ok", style: WKAlertActionStyle.cancel, handler: {})

class InterfaceController: WKInterfaceController {
    
    @IBOutlet var headline: WKInterfaceLabel!
    @IBOutlet var text1: WKInterfaceLabel!
    @IBOutlet var text2: WKInterfaceLabel!
    @IBOutlet var noticeHeadline: WKInterfaceLabel!
    @IBOutlet var notice: WKInterfaceLabel!
    @IBOutlet var loading: WKInterfaceLabel!
    @IBOutlet var loadingAnimationImage: WKInterfaceImage!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        self.pageState(loading: true);
        guard let dic = context as? [String: Any], let doWhat = dic["do"] as? String else {
            return;
        }
        switch doWhat {
        case "loading":
            self.pageState(loading: true);
            break;
        case "welcome":
            self.pageState(loading: false);
            break;
        default:
            self.pageState(loading: false);
        }
        if let error = dic["error"] as? String {
            self.presentAlert(withTitle: "Login Error", message: error, preferredStyle: .alert, actions: [okButton])
        }
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    public func pageState(loading: Bool = false) {
        var loadingState = true;
        var welcomeState = true;
        if loading {
            loadingState = false;
        } else {
            welcomeState = false;
        }
        self.headline.setHidden(welcomeState)
        self.text1.setHidden(welcomeState)
        self.text2.setHidden(welcomeState)
        self.noticeHeadline.setHidden(welcomeState)
        self.notice.setHidden(welcomeState)
        if !loadingState {
            self.loadingAnimationImage.setImageNamed("Activity");
            self.loadingAnimationImage.startAnimatingWithImages(in: NSMakeRange(0, 30), duration: 1.0, repeatCount: 0);
        }
        self.loadingAnimationImage.setHidden(loadingState);
    }
    
}
