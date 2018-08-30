//
//  AppDelegate.swift
//  SitnuWatch
//
//  Created by Nils Bergmann on 29.08.18.
//  Copyright © 2018 Nils Bergmann. All rights reserved.
//

import UIKit
import WatchConnectivity
import Promises
import Form

@UIApplicationMain
class AppDelegate: UIResponder, WCSessionDelegate, UIApplicationDelegate {
    
    var session = WCSession.default;
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.session = session;
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("sessionReachabilityDidChange(\(session.activationState))")
        if session.activationState == WCSessionActivationState.activated {
            DispatchQueue.main.async {
                if UIApplication.shared.keyWindow != nil, let controller = UIApplication.shared.keyWindow?.rootViewController as? ViewController {
                    controller.reloadData();
                }
            }
        }
    }

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session;
        }
        FORMDefaultStyle.apply()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func getUser() -> Promise<[String: Any]> {
        return Promise { fulfill, reject in
            self.session.sendMessage(["type": "currentUser"], replyHandler: { (result) in
                dump(result)
                if let account = result["account"] as? [String: Any] {
                    fulfill(account);
                } else {
                    reject(NSError(domain: "io.noim.webuntis", code: -1, userInfo: nil));
                }
            }, errorHandler: { (error) in
                reject(error);
            })
        }.timeout(5);
    }
    
    func login(server: String, school: String, username: String, password: String) -> Promise<(success: Bool, error: String)> {
        return Promise { fulfill, reject in
            self.session.sendMessage(["server": server, "school": school, "username": username, "password": password, "type": "login"], replyHandler: { result in
                dump(result)
                if let success = result["success"] as? Bool, success {
                    fulfill((success: true, error: ""));
                } else {
                    if let error = result["error"] as? String {
                        fulfill((success: false, error: error));
                    } else {
                        fulfill((success: false, error: "Unknown Error"));
                    }
                }
            }, errorHandler: { (error) in
                print("\(error)");
                fulfill((success: false, error: error.localizedDescription));
            });
        }.timeout(10);
    }
    
    func delete() -> Promise<Bool> {
        return Promise { fulfill, reject in
            self.session.sendMessage(["type": "delete"], replyHandler: { result in
                fulfill(true);
            }, errorHandler: { error in
                reject(error);
            });
        };
    }
    
}

