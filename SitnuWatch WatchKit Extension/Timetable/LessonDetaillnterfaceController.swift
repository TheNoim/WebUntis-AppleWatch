//
//  LessonDetaillnterfaceController.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import WatchKit
import Foundation
import WebUntis

class LessonDetaillnterfaceController: WKInterfaceController {

    @IBOutlet var subject: WKInterfaceLabel!
    @IBOutlet var RoomGroup: WKInterfaceGroup!
    @IBOutlet var room: WKInterfaceLabel!
    @IBOutlet var teacherGroup: WKInterfaceGroup!
    @IBOutlet var teacher: WKInterfaceLabel!
    @IBOutlet var textGroup: WKInterfaceGroup!
    @IBOutlet var klassen: WKInterfaceLabel!
    @IBOutlet var klassenGroup: WKInterfaceGroup!
    @IBOutlet var text: WKInterfaceLabel!
    @IBOutlet var subsGroup: WKInterfaceGroup!
    @IBOutlet var subsText: WKInterfaceLabel!
    @IBOutlet var courseGroup: WKInterfaceGroup!
    @IBOutlet var course: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        guard let lesson = context as? Lesson else {
            return;
        }
        
        var subjectText = "";
        if lesson.subjects.count == 0 {
            subjectText = "Unknown";
        }
        for (index, subject) in lesson.subjects.enumerated() {
            if index != 0 {
                subjectText += ", ";
            }
            subjectText += subject.longname;
        }
        self.subject.setText(subjectText);
        
        if lesson.rooms.count == 0 {
            self.RoomGroup.setHidden(true);
        } else {
            var roomText = "";
            for (index, room) in lesson.rooms.enumerated() {
                if index != 0 {
                    roomText += ", ";
                }
                roomText += room.longname;
            }
            self.room.setText(roomText);
        }
        
        if lesson.teachers.count == 0 {
            self.teacherGroup.setHidden(true);
        } else {
            var teacherText = "";
            for (index, teacher) in lesson.teachers.enumerated() {
                if index != 0 {
                    teacherText += ", ";
                }
                teacherText += teacher.longname;
            }
            self.teacher.setText(teacherText);
        }
        
        if lesson.klassen.count == 0 {
            self.klassenGroup.setHidden(true);
        } else {
            var klasseText = "";
            for (index, klasse) in lesson.klassen.enumerated() {
                if index != 0 {
                    klasseText += ", ";
                }
                klasseText += klasse.longname;
            }
            self.klassen.setText(klasseText);
        }
        
        if lesson.lessonText != "" && lesson.lessonText != lesson.studentGroup {
            self.text.setText(lesson.lessonText);
        } else {
            self.textGroup.setHidden(true);
        }
        
        if lesson.studentGroup != "" {
            self.course.setText(lesson.studentGroup);
        } else {
            self.courseGroup.setHidden(true);
        }
        
        if lesson.substitutionText != "" {
            self.subsText.setText(lesson.substitutionText);
        } else {
            self.subsGroup.setHidden(true);
        }
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
