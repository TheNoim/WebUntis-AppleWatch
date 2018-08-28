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

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    
    @IBOutlet var headline: WKInterfaceLabel!
    @IBOutlet var text1: WKInterfaceLabel!
    @IBOutlet var text2: WKInterfaceLabel!
    @IBOutlet var noticeHeadline: WKInterfaceLabel!
    @IBOutlet var notice: WKInterfaceLabel!
    @IBOutlet var loading: WKInterfaceLabel!
    
    public var session: WCSession = WCSession.default
    
    public var configured: Bool = false
    
    public var username: String?
    
    var defaultDate: Date {
         return Date()
        //return Calendar.current.date(byAdding: .day, value: 2, to: Date())!
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session;
        }
        print("Hello")
        self.pageState(loading: true);
        // Configure interface objects here.
        //guard let applicationContext = context as? [String: Any] else {
            //return;
        //}
        //self.session(self.session, didReceiveApplicationContext: applicationContext);
        let (success, account) = self.getWebUntisAccountConfiguration();
        if success, account != nil {
            // Account data is save. Now configure WebUntis
            self.configureWebUntis(account: account!);
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
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.session = session;
        print("WCSessionActivationState: \(activationState)");
        self.session(session, didReceiveApplicationContext: session.receivedApplicationContext);
    }
    
    func configureWebUntis(account: WebUntisAccount) {
        pageState(loading: true);
        WebUntis.default.setCredentials(server: account.server, username: account.username, password: account.password, school: account.school).then { success in
            if success {
                //self.presentController(withName: "Timetable", context: ["date": Date()])
                //WKInterfaceController.reloadRootControllers(withNamesAndContexts: [(name: "Timetable", context: ["date": Date()])]);
                WKInterfaceController.reloadRootPageControllers(withNames: ["Timetable"], contexts: [["date": self.defaultDate]], orientation: .horizontal, pageIndex: 0);
            } else {
                self.pageState(loading: false);
                self.presentAlert(withTitle: "Login Error", message: "The login failed.", preferredStyle: .alert, actions: [okButton])
            }
        }.catch { error in
            self.presentAlert(withTitle: "Login Error", message: error.localizedDescription, preferredStyle: .alert, actions: [okButton])
            self.updateContext(key: "error", with: error.localizedDescription);
            self.pageState(loading: false);
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        self.session = session;
        
        print("Received context: \(applicationContext)");
        
        var context: [String: Any] = applicationContext;
        
        if let delete = context["delete"] as? String, delete != "" {
            try? Locksmith.deleteDataForUserAccount(userAccount: delete, inService: "WebUntis");
            try? session.updateApplicationContext([:]);
            self.configured = false;
            self.pageState(loading: false);
            return;
        }
        
        guard let username: String = context["username"] as? String else {
            self.configured = false;
            self.pageState(loading: false);
            return;
        }
        guard let password = context["password"] as? String, let school = context["school"] as? String, let server = context["server"] as? String else {
            return;
        }
        try? session.updateApplicationContext([:]);
        // Save Account in KeyChain
        try? Locksmith.saveData(data: ["username": username, "password": password, "school": school, "server": server], forUserAccount: "WebUntisLogin", inService: "WebUntis");
        // Remove password from context. SECURITY FOR THE WIN
        // Get Account again
        let (success, account) = self.getWebUntisAccountConfiguration();
        if success, account != nil {
            // Account data is save. Now configure WebUntis
            self.configureWebUntis(account: account!);
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
    
    private func updateContext(key: String, with data: Any) {
        var oldContext = session.receivedApplicationContext;
        oldContext[key] = data;
        try? session.updateApplicationContext(oldContext);
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
        self.loading.setHidden(loadingState)
    }
    
}

extension Date {
    
    static func today() -> Date {
        return Date()
    }
    
    func next(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.Next,
                   weekday,
                   considerToday: considerToday)
    }
    
    func previous(_ weekday: Weekday, considerToday: Bool = false) -> Date {
        return get(.Previous,
                   weekday,
                   considerToday: considerToday)
    }
    
    func get(_ direction: SearchDirection,
             _ weekDay: Weekday,
             considerToday consider: Bool = false) -> Date {
        
        let dayName = weekDay.rawValue
        
        let weekdaysName = getWeekDaysInEnglish().map { $0.lowercased() }
        
        assert(weekdaysName.contains(dayName), "weekday symbol should be in form \(weekdaysName)")
        
        let searchWeekdayIndex = weekdaysName.index(of: dayName)! + 1
        
        let calendar = Calendar(identifier: .gregorian)
        
        if consider && calendar.component(.weekday, from: self) == searchWeekdayIndex {
            return self
        }
        
        var nextDateComponent = DateComponents()
        nextDateComponent.weekday = searchWeekdayIndex
        
        
        let date = calendar.nextDate(after: self,
                                     matching: nextDateComponent,
                                     matchingPolicy: .nextTime,
                                     direction: direction.calendarSearchDirection)
        
        return date!
    }
    
}

// MARK: Helper methods
extension Date {
    func getWeekDaysInEnglish() -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar.weekdaySymbols
    }
    
    enum Weekday: String {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    }
    
    enum SearchDirection {
        case Next
        case Previous
        
        var calendarSearchDirection: Calendar.SearchDirection {
            switch self {
            case .Next:
                return .forward
            case .Previous:
                return .backward
            }
        }
    }
}

func startAndEnd(of date : Date) -> (start : Date, end : Date) {
    var startDate = Date()
    var interval : TimeInterval = 0.0
    let _ = Calendar.current.dateInterval(of: .day, start: &startDate, interval: &interval, for: date)
    let endDate = startDate.addingTimeInterval(interval-1)
    return (start : startDate, end : endDate)
}
