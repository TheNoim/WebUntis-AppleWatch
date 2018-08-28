//
//  LessonRowController.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import WatchKit
import WebUntis

class LessonRowController: NSObject {

  @IBOutlet var group: WKInterfaceGroup!
  
  @IBOutlet var subjectLabel: WKInterfaceLabel!
  @IBOutlet var timeRangeGroup: WKInterfaceGroup!
  
  @IBOutlet var timeRangeStart: WKInterfaceLabel!
  
  @IBOutlet var timeRangeEnd: WKInterfaceLabel!
  
  @IBOutlet var timer: WKInterfaceTimer!
  
  var lesson: Lesson?
  
}
