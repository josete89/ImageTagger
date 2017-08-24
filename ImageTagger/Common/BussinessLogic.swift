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

struct Helper {
    
    typealias Line = (key:String,value:String)
    typealias NewState<A,B> = (ProgramState,FileIO<A,B>)
    
    func imageCountLabel(state:ProgramState) -> String {
        let currentIndex = state.currentIndex
        let numOfImages = state.directoryContent.count
        return "Image \(currentIndex) de \(numOfImages)"
    }
    
    func getImage(state:ProgramState) -> NSImage? {
        let imageUrl = state.directoryContent[state.currentIndex]
        return NSImage(contentsOf: imageUrl)
    }
    
    func saveAndNext<A,B>(state:ProgramState,fileWriter:FileIO<A,B>,input:A) -> NewState<A,B>{
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
    
    func canGoBack(state:ProgramState) -> Bool{
        return state.currentIndex > 0
    }
    
    func rewind(state:ProgramState) -> ProgramState {
        state.currentIndex -= 1
        return state
    }
    private func getLineDescription(line:String) -> String {
        guard let desc = line.componentsSeparatedByString(":").last
            else {
                print("Cannot get line content from -> -\(line)-")
                return ""
            }
        return desc
    }
    
    func getDescription(fileReader:FileIO<String,String>,state:ProgramState)-> String{
        let id = state
            .directoryContent[state.currentIndex]
            .deletingPathExtension()
            .lastPathComponent
        
        return fileReader.apply(id) |> getLineDescription
    }
    
    func fileSearchLine(_ fileHandle:FileHandle,by id:String) -> String {
        let fileData = fileHandle.availableData
        guard let currentData = String(data: fileData, encoding: .utf8)
            else {
                print("Cannot read file")
                return ""
            }
        guard let line = currentData
            .componentsSeparatedByString("\n")
            .filter({ $0.contains(id) })
            .first
            else {
                print("Cannot find the line")
                return ""
            }
        
        return line
    }
    
    func fileReplaceLine(fileHandle:FileHandle,data:Data){
        
        let fileData = fileHandle.readDataToEndOfFile()
        
        guard let dataToReplace = String(data: data, encoding: .utf8),
              let id = dataToReplace.componentsSeparatedByString(":").first,
              let currentData = String(data: fileData, encoding: .utf8)
            else {
                print("Cannot read file")
                return
            }
        
        let replaceIfNeeds: (String) -> String = { line in
            if line.contains(id){
                return dataToReplace
            }
            return line
        }
        
        guard let newData = currentData
            .componentsSeparatedByString("\n")
            .map(replaceIfNeeds)
            .joined()
            .data(using: .utf8)
            else {
                print("Cannot create new content")
                return
        }
        
        fileHandle.seek(toFileOffset: 0)
        fileHandle.write(newData)
        fileHandle.truncateFile(atOffset: newData.count |> UInt64.init)
    }
    
    
    
    func transform(_ line:Line) -> Data {
        guard let data = "\(line.key):\(line.value)\n".data(using: .utf8)
            else {
                fatalError("Cannot convert to bytes")
        }
        return data
    }
}
