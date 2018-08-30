//
//  LoginController.swift
//  SitnuWatch
//
//  Created by Nils Bergmann on 30.08.18.
//  Copyright © 2018 Nils Bergmann. All rights reserved.
//

import UIKit
import Form.FORMViewController
import NSJSONSerialization_ANDYJSONFile
import SVProgressHUD

class LoginController: FORMViewController {
    
    init() {
        let JSON = JSONSerialization.jsonObject(withContentsOfFile: "Form.json")
        super.init(json: JSON, andInitialValues: nil, disabled: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SVProgressHUD.setMaximumDismissTimeInterval(1.5);
        
        self.collectionView?.backgroundColor = UIColor.white;
        let fieldUpdatedBlock: FORMFieldFieldUpdatedBlock = { _, field in
            if field!.fieldID == "submit-button" {
                if self.dataSource.isValid == false {
                    self.dataSource.validate()
                } else {
                    guard let server = self.dataSource.values["server-url"] as? String, let password = self.dataSource.values["password"] as? String, let username = self.dataSource.values["username"] as? String, let school = self.dataSource.values["school"] as? String else {
                        return;
                    }
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate;
                    SVProgressHUD.show();
                    appDelegate.login(server: server, school: school, username: username, password: password).then { (success, error) in
                        if success {
                            SVProgressHUD.dismiss();
                            self.cancel();
                        } else {
                            SVProgressHUD.showError(withStatus: error);
                        }
                    }.catch { error in
                        SVProgressHUD.showError(withStatus: error.localizedDescription);
                    };
                }
            }
            if field!.fieldID == "cancel" {
                self.cancel();
            }
        }
        self.dataSource.fieldUpdatedBlock = fieldUpdatedBlock
    }

    func cancel() {
        guard let presentController = self.presentingViewController else {
            return;
        }
        presentController.dismiss(animated: true, completion: nil);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
