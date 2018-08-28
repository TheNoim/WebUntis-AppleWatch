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

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
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
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.getNextFullHour(), userInfo: nil) { (error) in
                        print("Finished Background refresh Task with error:");
                        dump(error);
                        backgroundTask.setTaskCompletedWithSnapshot(false)
                    }
                }.catch { error in
                    print(error);
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: self.getNextFullHour(), userInfo: nil) { (error) in
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
  
    func refresWebUntis() -> Promise<Any?> {
        return Promise { fullfill, reject in
            let (success, account) = self.getWebUntisAccountConfiguration();
            if !success {
                return reject(NSError(domain: "com.webuntis.background", code: -1, userInfo: nil));
            }
            self.configureWebUntis(account: account!).then { untis in
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
        
        for complication in complicationServer.activeComplications! {
            print("UPDATE COMPLICATION")
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    private func getWebUntisAccountConfiguration() -> (success: Bool, account: WebUntisAccount?) {
        guard let data: [String: Any] = Locksmith.loadDataForUserAccount(userAccount: "WebUntisLogin", inService: "WebUntis") else {
            return (success: false, account: nil);
        }
        guard let password = data["password"] as? String, let school = data["school"] as? String, let server = data["server"] as? String, let username = data["username"] as? String else {
            return (success: false, account: nil);
        }
        let account = WebUntisAccount(username: username, password: password, server: server, school: school);
        return (success: true, account: account);
    }
    
    func configureWebUntis(account: WebUntisAccount) -> Promise<WebUntis> {
        return Promise { fulfill, reject in
            let untis = WebUntis();
            untis.configureForOfflineUsage(server: account.server, username: account.username, password: account.password, school: account.school).then { success in
                if success {
                    fulfill(untis);
                } else {
                    reject(getWebUntisErrorBy(type: WebUntisError.UNAUTHORIZED, userInfo: nil));
                }
                }.catch { error in
                    reject(error);
            }
        }
    }
    
    func getNextFullHour()-> Date {
        var now = Date()
        var nowComponents = DateComponents()
        let calendar = Calendar.current
        nowComponents.year = Calendar.current.component(.year, from: now)
        nowComponents.month = Calendar.current.component(.month, from: now)
        nowComponents.day = Calendar.current.component(.day, from: now)
        nowComponents.hour = Calendar.current.component(.hour, from: now) + 1
        nowComponents.minute = 0
        nowComponents.second = 0
        nowComponents.timeZone = NSTimeZone.local
        now = calendar.date(from: nowComponents)!
        return now as Date
    }
}
