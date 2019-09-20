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
        handler([])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        let backupStart = Calendar.current.date(byAdding: .minute, value: -1, to: Calendar.current.date(byAdding: .day, value: -2, to: Date())!);
        self.getWebUntisInstanceAndConfigure().then { webuntis in
            let (start, _) = webuntis.getTimelineStartAndEnd();
            if start != nil {
                handler(start)
            } else {
                handler(backupStart);
            }
        }.catch { error in
            print(error);
            handler(backupStart)
        };
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        let backupEnd = Calendar.current.date(byAdding: .minute, value: 1, to: Calendar.current.date(byAdding: .day, value: 2, to: Date())!);
        self.getWebUntisInstanceAndConfigure().then { webuntis in
            let (_, end) = webuntis.getTimelineStartAndEnd();
            if end != nil {
                handler(end)
            } else {
                handler(backupEnd);
            }
        }.catch { error in
            print(error);
            handler(backupEnd)
        };
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
    
    func getEntries(complication: CLKComplication, start: Date, end: Date, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        print("getEntries(start: \(start) end: \(end)");
        self.getWebUntisInstanceAndConfigure().then { webuntis in
            webuntis.getTimetable(between: start, and: end, forceRefresh: false, startBackgroundRefresh: false).then { result in
                let sorted = result.getVisibleLessons().filter({ lesson in
                    return lesson.code != Code.Cancelled;
                }).sorted(by: { $0.start < $1.start });
                var entries: [CLKComplicationTimelineEntry] = [];
                var lastLessonEndDate: Date?;
                var lastLesson: Lesson?;
                if let breakTemplate = self.getBreakTemplateFor(for: 0, inList: sorted, for: complication.family) {
                    entries.append(CLKComplicationTimelineEntry(date: start, complicationTemplate: breakTemplate));
                }
                for (index, lesson) in sorted.enumerated() {
                    if let template = self.createTemplateFor(lesson: lesson, start: lesson.start, end: lesson.end, for: complication.family) {
                        let entry = CLKComplicationTimelineEntry(date: lesson.start, complicationTemplate: template);
                        entries.append(entry);
                        if index != (sorted.count - 1) {
                            if let breakTemplate = self.getBreakTemplateFor(for: index, inList: sorted, for: complication.family) {
                                entries.append(CLKComplicationTimelineEntry(date: lesson.end, complicationTemplate: breakTemplate));
                            }
                        }
                        lastLessonEndDate = lesson.end;
                        lastLesson = lesson;
                    }
                    
                }
                if lastLessonEndDate != nil && lastLesson != nil {
                    let template = CLKComplicationTemplateModularLargeStandardBody();
                    template.headerTextProvider = CLKSimpleTextProvider(text: "End of Timeline");
                    template.body1TextProvider = CLKSimpleTextProvider(text: "Last: " + self.infoString(lesson: lastLesson!));
                    
                    // Try to get next possible lesson first
                    self.getTimelineEndDate(for: complication, withHandler: { timelineEnd in
                        if timelineEnd != nil {
                            let lessons: [Lesson] = webuntis.getTimetableFromDatabase(between: lastLessonEndDate!, and: timelineEnd!).filter({ lesson in
                                return lesson.code != Code.Cancelled;
                            }).sorted(by: { $0.start < $1.start });
                            if lessons.count >= 1 {
                                if let breakTemplate = self.getBreakTemplateFor(for: -1, inList: lessons, for: complication.family) {
                                    // Now we have the next template
                                    entries.append(CLKComplicationTimelineEntry(date: lastLessonEndDate!, complicationTemplate: breakTemplate));
                                    handler(entries);
                                } else {
                                    // Something went wrong
                                    entries.append(CLKComplicationTimelineEntry(date: lastLessonEndDate!, complicationTemplate: template));
                                    handler(entries);
                                }
                            } else {
                                // No more lessons
                                entries.append(CLKComplicationTimelineEntry(date: lastLessonEndDate!, complicationTemplate: template));
                                handler(entries);
                            }
                        } else {
                            // No date?
                            entries.append(CLKComplicationTimelineEntry(date: lastLessonEndDate!, complicationTemplate: template));
                            handler(entries);
                        }
                    });
                } else {
                    handler(entries);
                }
            }.catch { error in
                print(error);
                handler(nil)
            };
        }.catch { error in
            print(error);
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        let end = Calendar.current.date(byAdding: .minute, value: 1, to: Calendar.current.date(byAdding: .day, value: 2, to: date)!);
        let start = date;
        self.getEntries(complication: complication, start: start, end: end!, withHandler: handler);
    }
    
    func createTemplateFor(lesson: Lesson, start: Date, end: Date, for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        switch (family) {
        case .modularLarge:
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
        default:
            return nil;
        }
    }
    
    func getBreakTemplateFor(for index: Int, inList: [Lesson], for family: CLKComplicationFamily) -> CLKComplicationTemplate? {
        switch (family) {
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody();
            let nextIndex = index + 1;
            if nextIndex >= inList.endIndex {
                return nil;
            }
            template.headerTextProvider = CLKSimpleTextProvider(text: "Break");
            template.body1TextProvider = CLKSimpleTextProvider(text: "Next: " + infoString(lesson: inList[nextIndex]));
            template.body2TextProvider = CLKRelativeDateTextProvider(date: inList[nextIndex].start, style: .timer, units: .second);
            return template;
        default:
            return nil;
        }
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
