//
//  ViewController.swift
//  yzLog
//
//  Created by Yz on 2019/4/17.
//  Copyright © 2019 Yz. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var count = 0
    
    @IBOutlet weak var logServerSwitch: UISwitch!
    override func viewDidLoad() {
        super.viewDidLoad()
        log.info("打印日志开始")
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { (ktimer) in
            self.count += 1
            log.info(self.count)
        }
        logServerSwitch.isOn = log.isHttpServerEnable()
    }

    @IBAction func logWindow(_ sender: UISwitch) {
        if sender.isOn {
            log.showLogWindow()
        }else{
            log.hiddenLogWindow()
        }
    }
    
    @IBAction func logServer(_ sender: UISwitch) {
        log.httpServer(enable: sender.isOn)
    }
}

