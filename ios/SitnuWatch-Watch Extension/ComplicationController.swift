//
//  ComplicationController.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import ClockKit
import WebUntis
import Promises
import Locksmith

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    override init() {
        super.init();
        DispatchQueue.promises = DispatchQueue(label: currentQueueName()!);
    }
    
    func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.forward, .backward])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        let start = Calendar.current.date(byAdding: .minute, value: -1, to: Calendar.current.date(byAdding: .day, value: -2, to: Date())!);
        handler(start)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        let end = Calendar.current.date(byAdding: .minute, value: 1, to: Calendar.current.date(byAdding: .day, value: 2, to: Date())!);
        handler(end)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        let start = Calendar.current.date(byAdding: .minute, value: -1, to: Calendar.current.date(byAdding: .day, value: -2, to: Date())!);
        let end = Calendar.current.date(byAdding: .minute, value: 1, to: Calendar.current.date(byAdding: .day, value: 2, to: Date())!);
        self.getEntries(complication: complication, start: start!, end: end!, withHandler: { complications in
            guard let array = complications else {
                handler(nil);
                return;
            }
            let newArray = array.filter({ entry in
                return entry.date >= start! && entry.date <= end!;
            });
            guard let cu = newArray.first else {
                handler(nil);
                return;
            }
            handler(cu);
        });
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        let start = Calendar.current.date(byAdding: .minute, value: -1, to: Calendar.current.date(byAdding: .day, value: -2, to: date)!);
        let end = date;
        self.getEntries(complication: complication, start: start!, end: end, withHandler: handler);
    }
    
    func getEntries(complication: CLKComplication, start: Date, end: Date, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        switch complication.family {
        case .modularLarge:
            self.getWebUntisInstanceAndConfigure().then { webuntis in
                webuntis.getTimetable(between: start, and: end, forceRefresh: false, startBackgroundRefresh: false).then { result in
                    let sorted = result.getVisibleLessons().sorted(by: { $0.start < $1.start });
                    var entries: [CLKComplicationTimelineEntry] = [];
                    for (index, lesson) in sorted.enumerated() {
                        if index == sorted.startIndex, start < lesson.start {
                            entries.append(CLKComplicationTimelineEntry(date: start, complicationTemplate: self.getBreakTemplateFor(for: index - 1, inList: sorted)));
                        }
                        if index != (sorted.endIndex - 1) {
                            let template = self.createTemplateFor(lesson: lesson, start: lesson.start, end: lesson.end);
                            let entry = CLKComplicationTimelineEntry(date: lesson.start, complicationTemplate: template);
                            entries.append(entry);
                            entries.append(CLKComplicationTimelineEntry(date: lesson.end, complicationTemplate: self.getBreakTemplateFor(for: index, inList: sorted)));
                        } else {
                            let template = self.createTemplateFor(lesson: lesson, start: lesson.start, end: end);
                            let entry = CLKComplicationTimelineEntry(date: lesson.start, complicationTemplate: template);
                            entries.append(entry);
                        }
                    }
                    handler(entries);
                    }.catch { error in
                        print(error);
                        handler(nil)
                };
                }.catch { error in
                    print(error);
                    handler(nil)
            }
            break;
        default:
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        let end = Calendar.current.date(byAdding: .minute, value: 1, to: Calendar.current.date(byAdding: .day, value: 2, to: date)!);
        let start = date;
        self.getEntries(complication: complication, start: start, end: end!, withHandler: handler);
    }
    
    func createTemplateFor(lesson: Lesson, start: Date, end: Date) -> CLKComplicationTemplateModularLargeStandardBody {
        let template = CLKComplicationTemplateModularLargeStandardBody();
        var subjects = "";
        if lesson.startGrid.timeHash != lesson.endGrid.timeHash, !lesson.startGrid.custom, !lesson.endGrid.custom {
            subjects += "\(lesson.startGrid.name)-\(lesson.endGrid.name) ";
        } else {
            if !lesson.startGrid.custom {
                subjects += "\(lesson.startGrid.name) ";
            }
        }
        for (index, subject) in lesson.subjects.enumerated() {
            subjects += subject.name + ((lesson.subjects.count - 1) == index ? " " : " & ");
        }
        let subjectTextProvider = CLKSimpleTextProvider(text: "\(subjects)");
        if let firstSubject = lesson.subjects.first {
            subjectTextProvider.tintColor = UIColor(hexString: firstSubject.backgroundColor);
        }
        template.headerTextProvider = subjectTextProvider
        template.body1TextProvider = CLKSimpleTextProvider(text: infoStringLesson(lesson: lesson));
        template.body2TextProvider = CLKRelativeDateTextProvider(date: lesson.end, style: .timer, units: .second);
        return template;
    }
    
    func getBreakTemplateFor(for index: Int, inList: [Lesson]) -> CLKComplicationTemplateModularLargeStandardBody {
        let template = CLKComplicationTemplateModularLargeStandardBody();
        let nextIndex = index + 1;
        if nextIndex > (inList.endIndex - 1) || nextIndex < inList.startIndex {
            template.headerTextProvider = CLKSimpleTextProvider(text: "Break");
            template.body1TextProvider = CLKSimpleTextProvider(text: "Next: " + "Nothing");
        } else {
            template.headerTextProvider = CLKSimpleTextProvider(text: "Break");
            template.body1TextProvider = CLKSimpleTextProvider(text: "Next: " + infoString(lesson: inList[nextIndex]));
            template.body2TextProvider = CLKRelativeDateTextProvider(date: inList[nextIndex].start, style: .timer, units: .second);
        }
        return template;
    }
    
    func infoStringLesson(lesson: Lesson) -> String {
        var string = "";
        for (index, room) in lesson.rooms.enumerated() {
            if string == "" {
                string += "In ";
            }
            string += room.name + ((lesson.rooms.count - 1) == index ? " " : " & ");
        }
        if string == "" {
            string += "By ";
        } else {
            string += "by ";
        }
        for (index, teacher) in lesson.teachers.enumerated() {
            string += teacher.name + ((lesson.teachers.count - 1) == index ? " " : " & ");
        }
        return string;
    }
    
    func infoString(lesson: Lesson) -> String {
        var string = "";
        for (index, subject) in lesson.subjects.enumerated() {
            string += subject.name + ((lesson.subjects.count - 1) == index ? " " : ",");
        }
        if lesson.rooms.count > 0 {
            string += "in ";
            for (index, room) in lesson.rooms.enumerated() {
                string += room.name + ((lesson.rooms.count - 1) == index ? " " : ",");
            }
        }
        return string;
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        handler(nil)
    }
    
    func getWebUntisInstanceAndConfigure() -> Promise<WebUntis> {
        return Promise { fulfill, reject in
            let (success, account) = self.getWebUntisAccountConfiguration();
            if success, account != nil {
                self.configureWebUntis(account: account!).then { untis in
                    return fulfill(untis);
                }.catch { error in
                    print("LoL");
                    reject(error);
                }
            } else {
                reject(getWebUntisErrorBy(type: WebUntisError.UNAUTHORIZED, userInfo: nil));
            }
        };
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
}
