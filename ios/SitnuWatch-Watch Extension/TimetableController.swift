//
//  TimetableController.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import WatchKit
import WebUntis
import WatchConnectivity
import ClockKit

class TimetableController: WKInterfaceController, WCSessionDelegate {
    
    public static var requestedRefresh = false;
    
    private var start = Date()
    private var end = Date()
    
    @IBOutlet var timetable: WKInterfaceTable!
    
    @IBOutlet var headDate: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context);
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        var date = Date();
        if let dic = context as? [String: Any], let contextDate = dic["date"] as? Date {
            date = contextDate;
        }
        print(date)
        let (start, end) = startAndEnd(of: date);
        self.start = start;
        self.end = end;
        self.update();
        WebUntis.default.listenTo(eventName: "refresh", action: { self.update() });
        
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: getNextFullHour(), userInfo: nil) { (error) in
            print("Finished Background refresh Task with error:");
            dump(error);
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
    
    override func willActivate() {
        super.willActivate()
        self.headDate.setText(self.getTimeRelativeString(date: self.start));
        self.updateTimeButtons();
        WebUntis.default.removeListeners(eventNameToRemoveOrNil: "refresh");
        WebUntis.default.listenTo(eventName: "refresh", action: { self.update() });
        self.update();
    }
    
    override func willDisappear() {
        super.willDisappear();
        WebUntis.default.removeListeners(eventNameToRemoveOrNil: "refresh");
    }
    
    func updateComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        
        for complication in complicationServer.activeComplications! {
            print("UPDATE COMPLICATION")
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    func update(forceRefresh: Bool = false) {
        if !TimetableController.requestedRefresh {
            TimetableController.requestedRefresh = true;
            self.updateComplication();
        }
        WebUntis.default.getTimetable(between: self.start, and: self.end, forceRefresh: forceRefresh, startBackgroundRefresh: false).then { result in
            self.updateUI(lessons: result);
        }.catch { error in
            print("Error: \(error)")
        }
    }
    
    func updateUI(lessons: [Lesson]) {
        if lessons.count == 0 {
            self.timetable.setRowTypes(["NothingTodayRowController"]);
        } else {
            var allLessons: [Lesson] = lessons.filter({ lesson in
                return lesson.type == LessonType.Lesson
            }).getVisibleLessons().sorted(by: { $0.start < $1.start });
            var rowControllerTypeArray: [String] = [];
            for _ in 0..<allLessons.count {
                rowControllerTypeArray.append("LessonRowController");
            }
            self.timetable.setRowTypes(rowControllerTypeArray);
            for lessonA in allLessons.enumerated() {
                var lesson = lessonA.element;
                var controller = self.timetable.rowController(at: lessonA.offset) as! LessonRowController;
                var Color = "ffffff"
                var subjectLabel: String {
                    var string = "";
                    if lesson.startGrid.timeHash != lesson.endGrid.timeHash {
                        string = "\(lesson.startGrid.custom ? "C" : lesson.startGrid.name)-\(lesson.endGrid.custom ? "C" : lesson.endGrid.name) ";
                    } else {
                        string = "\(lesson.startGrid.custom ? "C" : lesson.startGrid.name) ";
                    }
                    if lesson.subjects.count == 0 {
                        return string + "Unknown"
                    } else {
                        for subject in lesson.subjects.enumerated() {
                            if subject.offset == 0 {
                                Color = subject.element.backgroundColor;
                                string = string + subject.element.longname;
                            } else {
                                string = string + ", " + subject.element.longname;
                            }
                        }
                        return string;
                    }
                }
                if lesson.code == Code.Cancelled {
                    controller.subjectLabel.setAttributedText(NSAttributedString(string: subjectLabel, attributes: [NSAttributedStringKey.strikethroughStyle: 1]));
                    controller.timeRangeStart.setAttributedText(NSAttributedString(string: self.getTimeFormatted(date: lesson.start), attributes: [NSAttributedStringKey.strikethroughStyle: 1]))
                    controller.timeRangeEnd.setAttributedText(NSAttributedString(string: self.getTimeFormatted(date: lesson.end), attributes: [NSAttributedStringKey.strikethroughStyle: 1]))
                } else {
                    controller.subjectLabel.setText(subjectLabel);
                    controller.timeRangeStart.setText(self.getTimeFormatted(date: lesson.start));
                    controller.timeRangeEnd.setText(self.getTimeFormatted(date: lesson.end));
                }
                controller.subjectLabel.setTextColor(UIColor(hexString: Color))
                controller.timer.setHidden(true);
                controller.lesson = lesson;
            }
        }
    }
    
    func getTimeFormatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm";
        return formatter.string(from: date);
    }
    
    var reloading = false;
    @IBOutlet var reloadDataButton: WKInterfaceButton!
    @IBAction func reloadData() {
        if !reloading {
            self.reloading = true;
            self.reloadDataButton.setTitle("Reloading...");
            self.reloadDataButton.setBackgroundColor(UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0));
            WebUntis.default.getTimetable(between: self.start, and: self.end, forceRefresh: true).then { result in
                self.reloading = false;
                self.reloadDataButton.setTitle("Reload Data");
                self.reloadDataButton.setBackgroundColor(UIColor.darkGray);
                DispatchQueue.main.async {
                    self.updateComplication();
                    self.updateUI(lessons: result);
                };
            }.catch { error in
                self.reloading = false;
                self.reloadDataButton.setTitle("Reload Data");
                self.reloadDataButton.setBackgroundColor(UIColor.darkGray);
            }
        }
    }
    
    func getTimeRelativeString(date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today";
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow";
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday";
        } else {
            let formatter = DateFormatter();
            formatter.dateFormat = "dd.MM.yyyy";
            return formatter.string(from: date);
        }
    }
    
    func updateTimeButtons() {
        self.nextButton.setTitle(self.getTimeRelativeString(date: Calendar.current.date(byAdding: .day, value: 1, to: self.start)!));
        self.backButton.setTitle(self.getTimeRelativeString(date: Calendar.current.date(byAdding: .day, value: -1, to: self.start)!));
    }
    
    @IBOutlet var nextButton: WKInterfaceButton!
    @IBAction func nextAction() {
        WKInterfaceController.reloadRootPageControllers(withNames: ["Timetable"], contexts: [["date": Calendar.current.date(byAdding: .day, value: 1, to: self.start)!]], orientation: .horizontal, pageIndex: 0);
    }
    @IBOutlet var backButton: WKInterfaceButton!
    @IBAction func backAction() {
        WKInterfaceController.reloadRootPageControllers(withNames: ["Timetable"], contexts: [["date": Calendar.current.date(byAdding: .day, value: -1, to: self.start)!]], orientation: .horizontal, pageIndex: 0);
    }
    
    @IBAction func backToToday() {
        WKInterfaceController.reloadRootPageControllers(withNames: ["Timetable"], contexts: [["date": Date()]], orientation: .horizontal, pageIndex: 0);
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        self.session(session, didReceiveApplicationContext: session.receivedApplicationContext);
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        var context: [String: Any] = applicationContext;
        if let delete = context["delete"] as? String, delete != "" {
            WKInterfaceController.reloadRootPageControllers(withNames: ["Welcome"], contexts: [["context": context]], orientation: .horizontal, pageIndex: 0);
        }
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        guard let controller = self.timetable.rowController(at: rowIndex) as? LessonRowController else {
            return;
        }
        guard let lesson = controller.lesson else {
            return;
        }
        self.presentController(withName: "LessonDetail", context: lesson);
    }
    
}

extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}
