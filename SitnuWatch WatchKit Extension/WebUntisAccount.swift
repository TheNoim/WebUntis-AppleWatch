//
//  WebUntisAccount.swift
//  SitnuWatch-Watch Extension
//
//  Created by Nils Bergmann on 26.08.18.
//  Copyright © 2018 Facebook. All rights reserved.
//

import Foundation

struct WebUntisAccount {
    let username: String
    let password: String
    let server: String
    let school: String
    
    init(username: String, password: String, server: String, school: String) {
        self.username = username;
        self.password = password;
        self.server = server;
        self.school = school;
    }
    
    var dic: [String: Any] {
        return ["username": self.username, "server": self.server, "school": self.school]
    }
}
