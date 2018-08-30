//
//  ExtensionDelegate.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import WatchKit
import Promises
import WebUntis
import Locksmith
import ClockKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WCSessionDelegate, WKExtensionDelegate {

    var defaultDate: Date {
        return Date()
        //return Calendar.current.date(byAdding: .day, value: 2, to: Date())!
    }
    
    var session: WCSession = WCSession.default;
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session;
        }
        self.doLogin();
    }
    
    override init() {
        super.init();
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                self.refresWebUntis().then { _ in
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: getNextFullHour(), userInfo: nil) { (error) in
                        print("Finished Background refresh Task with error:");
                        dump(error);
                        backgroundTask.setTaskCompletedWithSnapshot(false)
                    }
                }.catch { error in
                    print(error);
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: getNextFullHour(), userInfo: nil) { (error) in
                        print("Finished Background refresh Task with error:");
                        dump(error);
                        backgroundTask.setTaskCompletedWithSnapshot(false)
                    }
                };
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    func doLogin(completion: @escaping (Error?) -> Void = { _ in } ) {
        let (success, account) = WebUntisAccountMangement.getWebUntisAccountConfiguration();
        if success, account != nil {
            WKInterfaceController.reloadRootPageControllers(withNames: ["Welcome"], contexts: [["do": "loading"]], orientation: .horizontal, pageIndex: 0);
            WebUntisAccountMangement.configureWebUntis(account: account!).then { _ in
                WKInterfaceController.reloadRootPageControllers(withNames: ["Timetable"], contexts: [["date": self.defaultDate]], orientation: .horizontal, pageIndex: 0);
                completion(nil);
            }.catch { error in
                WKInterfaceController.reloadRootPageControllers(withNames: ["Welcome"], contexts: [["do": "welcome", "error": error.localizedDescription]], orientation: .horizontal, pageIndex: 0);
                completion(error);
            };
        } else {
            WKInterfaceController.reloadRootPageControllers(withNames: ["Welcome"], contexts: [["do": "welcome"]], orientation: .horizontal, pageIndex: 0);
            completion(getWebUntisErrorBy(type: .UNAUTHORIZED, userInfo: nil));
        }
    }
  
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        dump(message);
        guard let type = message["type"] as? String else {
            return replyHandler([:]);
        }
        switch type {
        case "login":
            guard let username = message["username"] as? String, let password = message["password"] as? String, let school = message["school"] as? String, let server = message["server"] as? String else {
                return replyHandler([:]);
            }
            try? Locksmith.saveData(data: ["username": username, "password": password, "school": school, "server": server], forUserAccount: "WebUntisLogin", inService: "WebUntis");
            self.doLogin(completion: { error in
                if error == nil {
                    replyHandler(["success": true]);
                } else {
                    try? Locksmith.deleteDataForUserAccount(userAccount: "WebUntisLogin", inService: "WebUntis");
                    replyHandler(["error": error!.localizedDescription]);
                }
            });
            break;
        case "currentUser":
            var (success, account) = WebUntisAccountMangement.getWebUntisAccountConfiguration();
            if success, account != nil {
                replyHandler(["account": account!.dic]);
            } else {
                replyHandler([:]);
            }
            break;
        case "delete":
            try? Locksmith.deleteDataForUserAccount(userAccount: "WebUntisLogin", inService: "WebUntis");
            WKInterfaceController.reloadRootPageControllers(withNames: ["Welcome"], contexts: [["do": "welcome"]], orientation: .horizontal, pageIndex: 0);
            replyHandler([:]);
            break;
        default:
            replyHandler([:]);
        }
    }
    
    func refresWebUntis() -> Promise<Any?> {
        return Promise { fullfill, reject in
            let (success, account) = WebUntisAccountMangement.getWebUntisAccountConfiguration();
            if !success {
                return reject(NSError(domain: "com.webuntis.background", code: -1, userInfo: nil));
            }
            WebUntisAccountMangement.configureWebUntisOffline(account: account!).then { untis in
                untis.getTimetable(between: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, and: Calendar.current.date(byAdding: .day, value: 2, to: Date())!, forceRefresh: true, startBackgroundRefresh: false).then { result in
                    self.updateComplication();
                    fullfill(nil);
                }.catch { error in
                    reject(error);
                };
            }.catch { error in
                reject(error);
            };
        };
    }
    
    func updateComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        if complicationServer.activeComplications != nil {
            for complication in complicationServer.activeComplications! {
                print("UPDATE COMPLICATION")
                complicationServer.reloadTimeline(for: complication)
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.session = session;
    }
}
