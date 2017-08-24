//
//  FileIO.swift
//  ImageTagger
//
//  Created by Alcala, Jose Luis on 8/24/17.
//  Copyright © 2017 Alcala, Jose Luis. All rights reserved.
//

import Cocoa

final class FileIO<A,B> {
    
    let fileHandle:FileHandle
    let path:URL
    let fileManager = FileManager.default
    typealias Line = (key:String,value:String)
    
    let f:(FileHandle,A) -> B
    
    init(path:URL,f:@escaping (FileHandle,A) -> B){
        let stringPath = path.absoluteString.replacingOccurrences(of: "file://", with: "")
        if !fileManager.fileExists(atPath: stringPath) {
            let result = fileManager.createFile(atPath: stringPath, contents: nil, attributes: nil)
            print("Created label file \(result)")
        }
        self.fileHandle = try! FileHandle(forUpdating: path)
        self.f = f
        self.path = path
    }
    
    func apply(_ a:A) -> B {
        return f(fileHandle,a)
    }
    
    func map<C>(f: @escaping (B) -> C ) -> FileIO<A,C> {
        return FileIO<A,C>(path: self.path, f: { (file:FileHandle,arg:A) -> C in
            f(self.f(file,arg))
        })
    }
    
    func flatMap<C>(f: @escaping (B) -> FileIO<A,C> ) -> FileIO<A,C>{
        return FileIO<A,C>(path:path,f:{ (file:FileHandle,arg:A) -> C in
            f(self.f(file,arg)).f(file,arg)
        })
    }
    
    deinit {
        fileHandle.closeFile()
    }
    
}
