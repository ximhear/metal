//
//  SBLog.swift
//  kulan
//
//  Created by daeung Kim on 2017. 5. 16..
//  Copyright © 2017년 misociety. All rights reserved.
//
import Foundation
import SwiftyBeaver

open class SBLog {
    
    // log object
    private let swiftBeaverLog: SwiftyBeaver.Type = SwiftyBeaver.self
    
    /// singleton instance
    private static let instance: SBLog = {
        let instance = SBLog.init()
        
        // consol object
        let console: ConsoleDestination = ConsoleDestination()
        console.asynchronously = false
        
        instance.swiftBeaverLog.addDestination(console)
        
        return instance
    }()
    
    /// 외부에서 인스턴스 생성 금지
    private init() {
        
    }
    
    /// log something generally unimportant (lowest priority)
    static func verbose(_ message: @autoclosure () -> Any = String(), _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        
        let instance = SBLog.instance
        instance.swiftBeaverLog.verbose(message, file, function, line: line)
    }
    
    /// log something which help during debugging (low priority)
    static func debug(_ message: @autoclosure () -> Any = String(), _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        
        let instance = SBLog.instance
        instance.swiftBeaverLog.debug(message, file, function, line: line)
    }
    
    /// log something which you are really interested but which is not an issue or error (normal priority)
    static func info(_ message: @autoclosure () -> Any = String(), _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        
        let instance = SBLog.instance
        instance.swiftBeaverLog.info(message, file, function, line: line)
    }
    
    /// log something which may cause big trouble soon (high priority)
    static func warning(_ message: @autoclosure () -> Any = String(), _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        
        let instance = SBLog.instance
        instance.swiftBeaverLog.warning(message, file, function, line: line)
    }
    
    /// log something which will keep you awake at night (highest priority)
    static func error(_ message: @autoclosure () -> Any = String(), _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        
        let instance = SBLog.instance
        instance.swiftBeaverLog.error(message, file, function, line: line)
    }
}
