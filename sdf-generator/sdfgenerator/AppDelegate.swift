//
//  AppDelegate.swift
//  sdfgenerator
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        let fontManager = NSFontManager.init()
        for font in fontManager.availableFonts {
            GZLogFunc("\(font)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

