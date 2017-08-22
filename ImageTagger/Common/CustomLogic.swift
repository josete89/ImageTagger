//
//  CustomLogic.swift
//  ImageTagger
//
//  Created by Alcala, Jose Luis on 8/21/17.
//  Copyright © 2017 Alcala, Jose Luis. All rights reserved.
//

import Cocoa
import Swiftz

final class ProgramState:Codable {
    
    let path:String
    fileprivate var currentIndex = 0
    
    fileprivate lazy var directoryContent:[URL] = {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let files =  try! fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .sorted(by: { (a, b) -> Bool in
                    return a.lastPathComponent < b.lastPathComponent
                })
        return files.filter({ $0.pathExtension == "jpg" })
    }()
    
    init(path:String){
        self.path = path
    }
    
}

final class FileWriter<A,B> {
    
    let fileHandle:FileHandle
    let path:URL
    let fileManager = FileManager.default
    typealias Line = (key:String,value:String)
    
    let f:(FileHandle,A) -> B
    
    init(path:URL,f:@escaping (FileHandle,A) -> B){
        let stringPath = path.absoluteString.replacingOccurrences(of: "file://", with: "")
        if !fileManager.fileExists(atPath: stringPath) {
            let result = fileManager.createFile(atPath: stringPath, contents: nil, attributes: nil)
            print("Created file \(result)")
        }
        self.fileHandle = try! FileHandle(forWritingTo: path)
        self.f = f
        self.path = path
    }
    
    func apply(_ a:A) -> B {
        return f(fileHandle,a)
    }
    
    func map<C>(f: @escaping (B) -> C ) -> FileWriter<A,C> {
        return FileWriter<A,C>(path: self.path, f: { (file:FileHandle,arg:A) -> C in
            f(self.f(file,arg))
        })
    }
    
    func flatMap<C>(f: @escaping (B) -> FileWriter<A,C> ) -> FileWriter<A,C>{
        return FileWriter<A,C>(path:path,f:{ (file:FileHandle,arg:A) -> C in
            f(self.f(file,arg)).f(file,arg)
        })
    }

    deinit {
        fileHandle.closeFile()
    }
    
}

struct Helper {
    
    typealias Line = (key:String,value:String)
    typealias NewState<A,B> = (ProgramState,FileWriter<A,B>)
    
    func imageCountLabel(state:ProgramState) -> String {
        let currentIndex = state.currentIndex
        let numOfImages = state.directoryContent.count
        return "Image \(currentIndex) de \(numOfImages)"
    }
    
    func getImage(state:ProgramState) -> NSImage? {
        let imageUrl = state.directoryContent[state.currentIndex]
        return NSImage(contentsOf: imageUrl)
    }
    
    func saveAndNext<A,B>(state:ProgramState,fileWriter:FileWriter<A,B>,input:A) -> NewState<A,B>{
        _ = fileWriter.apply(input)
        state.currentIndex += 1
        return (state,fileWriter)
    }
    
    func getImageName(state:ProgramState) -> String {
        return state.directoryContent[state.currentIndex]
            .deletingPathExtension()
            .lastPathComponent
    }
    
    func fileAppend(fileHandle:FileHandle,data:Data){
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
    }
    
    func transform(_ line:Line) -> Data {
        guard let data = "\(line.key):\(line.value)\n".data(using: .utf8)
            else {
                fatalError("Cannot convert to bytes")
        }
        return data
    }
}
