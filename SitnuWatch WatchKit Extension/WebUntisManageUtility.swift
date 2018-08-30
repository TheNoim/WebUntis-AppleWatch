//
//  WebUntisManageUtility.swift
//  SitnuWatch WatchKit Extension
//
//  Created by Nils Bergmann on 30.08.18.
//  Copyright © 2018 Nils Bergmann. All rights reserved.
//

import Foundation
import Locksmith
import Promises
import WebUntis

class WebUntisAccountMangement {
    
    public static func getWebUntisAccountConfiguration() -> (success: Bool, account: WebUntisAccount?) {
        guard let data: [String: Any] = Locksmith.loadDataForUserAccount(userAccount: "WebUntisLogin", inService: "WebUntis") else {
            return (success: false, account: nil);
        }
        guard let password = data["password"] as? String, let school = data["school"] as? String, let server = data["server"] as? String, let username = data["username"] as? String else {
            return (success: false, account: nil);
        }
        let account = WebUntisAccount(username: username, password: password, server: server, school: school);
        return (success: true, account: account);
    }
    
    public static func configureWebUntisOffline(account: WebUntisAccount) -> Promise<WebUntis> {
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
    
    public static func configureWebUntis(account: WebUntisAccount) -> Promise<Any?> {
        return Promise { fulfill, reject in
            WebUntis.default.setCredentials(server: account.server, username: account.username, password: account.password, school: account.school).then { success in
                if success {
                    fulfill(nil);
                } else {
                    reject(getWebUntisErrorBy(type: WebUntisError.UNAUTHORIZED, userInfo: nil));
                }
            }.catch { error in
                reject(error);
            }
        }
    }
    
}
