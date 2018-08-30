//
//  ViewController.swift
//  SitnuWatch
//
//  Created by Nils Bergmann on 29.08.18.
//  Copyright © 2018 Nils Bergmann. All rights reserved.
//

import UIKit
import SVProgressHUD
import ESPullToRefresh
import Promises

class ViewController: UIViewController {
    
    @IBOutlet var controller: UIView!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBAction func loginModal() {
        let loginController = LoginController();
        if UIDevice.current.userInterfaceIdiom == .pad {
            loginController.modalPresentationStyle = .formSheet
        }
        self.present(loginController, animated: true, completion: nil);
    }
    
    @IBAction func delete() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;
        SVProgressHUD.show();
        appDelegate.delete().then { _ in
            SVProgressHUD.dismiss();
            self.reloadData();
        }.catch { error in
            SVProgressHUD.showError(withStatus: error.localizedDescription);
            self.reloadData();
        }
    }
    
    var reloading = false;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SVProgressHUD.setMaximumDismissTimeInterval(1.5);
        // Do any additional setup after loading the view, typically from a nib.
        self.scrollView.isScrollEnabled = true;
        self.scrollView.alwaysBounceVertical = true;
        self.scrollView.es.addPullToRefresh {
            if !self.reloading {
                self.reloading = true;
                self.refresh().then { result in
                    self.scrollView.es.stopPullToRefresh();
                    self.reloading = false;
                }.catch { error in
                    print("\(error)");
                    self.reloading = false;
                };
            }
        }
        self.reloadData();
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.reloadData();
    }
    
    func reloadData() {
        if !reloading {
            reloading = true;
            self.scrollView.es.startPullToRefresh();
            self.refresh().then { result in
                self.scrollView.es.stopPullToRefresh();
                self.reloading = false;
            }.catch { error in
                print("\(error)");
                self.reloading = false;
            };
        }
    }
    
    func refresh() -> Promise<Bool> {
        return Promise { fulfill, reject in
            let appDelegate = UIApplication.shared.delegate as! AppDelegate;
            SVProgressHUD.show();
            appDelegate.getUser().then { user in
                if let username = user["username"] as? String {
                    SVProgressHUD.showSuccess(withStatus: "Current User: \(username)");
                    self.showUser(with: username);
                    fulfill(true);
                } else {
                    fulfill(false);
                }
            }.catch { error in
                if (error as NSError).code == -1 {
                    fulfill(true);
                    self.showLoginButton();
                    SVProgressHUD.dismiss();
                } else {
                    SVProgressHUD.showError(withStatus: error.localizedDescription);
                    fulfill(false);
                }
            };
        };
    }

    func showUser(with username: String) {
        self.userLabel.text = "User: \(username)";
        self.userLabel.isHidden = false;
        self.deleteButton.isHidden = false;
        self.loginButton.isHidden = true;
    }
    
    func showLoginButton() {
        self.userLabel.isHidden = true;
        self.deleteButton.isHidden = true;
        self.loginButton.isHidden = false;
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

