//
//  AppDelegate.swift
//  NonCertifiedCamera
//
//  Created by Takuma Horiuchi on 2017/11/05.
//  Copyright © 2017年 Takuma Horiuchi. All rights reserved.
//

import UIKit
import TwitterKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Twitter.sharedInstance().start(withConsumerKey: "rWNwtXl3yMaQBWVtFj52FluW5", consumerSecret: "ChB50oEB8s3HSfFaVKxiYihw8wbqZFf7jsLUQRlWkqbkoqeIMb")
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return Twitter.sharedInstance().application(app, open: url, options: options)
    }
}
