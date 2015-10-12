//
//  ShellTasker.swift
//  droptogif
//
//  Created by Morten Just Petersen on 10/6/15.
//  Copyright (c) 2015 Morten Just Petersen. All rights reserved.
//

import Cocoa


protocol ShellTaskDelegate {
    func shellTaskDidBegin()
    func shellTaskDidFinish(output:String)
    func shellTaskDidUpdate(update:String)
}

class ShellTasker: NSObject {
    var scriptFile:String!
    var task:NSTask!
    var delegate:ShellTaskDelegate!
    var observer:NSObjectProtocol!

    
    init(scriptFile:String){
        self.scriptFile = scriptFile
    }
    
    func stop(){
        task.terminate()
    }
    
    func run(arguments args:[String]=[], complete:(output:NSString)-> Void) {
        
        
        if scriptFile == nil {
            return
        }
        
        print("running \(scriptFile)")
        
        let sp:AnyObject = NSBundle.mainBundle().pathForResource(scriptFile, ofType: "") as! AnyObject
        
        let scriptPath = sp as! String
        let tempPath:String = NSBundle.mainBundle().pathForResource("convert", ofType: "")!;
        let tempUrl:NSURL = NSURL(fileURLWithPath: tempPath);
//        let tempUrl:NSURL = NSURL(string: tempPath)!;
        
        
        let resourcesPath = tempUrl.URLByDeletingLastPathComponent?.path!;
        let bash = "/bin/bash"
        task = NSTask()
        let pipe = NSPipe()
        task.launchPath = bash

        // build entire command as arguments to /bin/bash
        var allArguments = [String]()
        allArguments.append("\(scriptPath)") //
        allArguments.append(resourcesPath!) // the script sees this as $1

        for arg in args {
            allArguments.append(arg)
        }
        
        task.arguments = allArguments
        
//        var i = 0
//        for a in task.arguments! {
//            print("argument \(i++): \(a)")
//        }
        
        print(task.arguments!);
        
        task.standardOutput = pipe
        self.task.launch()
        delegate.shellTaskDidBegin()
        
        
        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        
        observer = NSNotificationCenter.defaultCenter().addObserverForName(NSFileHandleDataAvailableNotification, object: pipe.fileHandleForReading, queue: nil) { (notification) -> Void in
            
            self.updateOrEndOfFile(notification, complete: complete)
        
        }
        
  
    }
    
    
    private func updateOrEndOfFile(notification:NSNotification, complete:(output:NSString) -> Void){
        var isEOF = false;
        let handle = notification.object as! NSFileHandle
        var data = handle.availableData
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            
            if(data.length>0){
                let s = NSString(data: data, encoding: NSUTF8StringEncoding)

                self.delegate.shellTaskDidUpdate(s! as String)
                
                NSNotificationCenter.defaultCenter().postNotificationName("mj.newData", object: s!)
                isEOF = false
            } else {
                isEOF = true
                data = handle.readDataToEndOfFile()
                var output = NSString()
                output = NSString(data: data, encoding: NSUTF8StringEncoding)!
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in

                    // todo: make sure this one only gets called once per file
                    self.delegate.shellTaskDidFinish(output as String)
                    NSNotificationCenter.defaultCenter().removeObserver(self.observer)
                    complete(output: output)
                })
            }
        })
        
        if isEOF == false {
            handle.waitForDataInBackgroundAndNotify()
        }
        else {
            
        }
    }
}