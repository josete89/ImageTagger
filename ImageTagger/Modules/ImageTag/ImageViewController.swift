//
//  ImageViewController.swift
//  ImageTagger
//
//  Created by Alcala, Jose Luis on 8/20/17.
//  Copyright © 2017 Alcala, Jose Luis. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import Swiftz

final class ImageViewController: NSViewController {
    
    let disposeBag = DisposeBag()
    var path:String?
    var didRewind:Bool = false
    
    let helper:Helper = Helper()
    lazy var state:ProgramState = {
        guard let path = self.path else {  fatalError() }
        return ProgramState(path: path)
    }()
    
    lazy var fileWriter:FileIO<Data,Void> = {
        guard let path = self.path else {  fatalError() }
        let url = URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("final_labels.txt")
        return  FileIO(path: url, f:self.helper.fileAppend)
    }()
    
    lazy var lineReplacer:FileIO<Data,Void> = {
        guard let path = self.path else {  fatalError() }
        let url = URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("final_labels.txt")
        return FileIO(path: url, f:self.helper.fileReplaceLine)
    }()
    
    lazy var fileSearcher:FileIO<String,String> = {
        guard let path = self.path else {  fatalError() }
        let url = URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("final_labels.txt")
        return FileIO(path: url, f:self.helper.fileSearchLine)
    }()
    
    
    @IBOutlet weak var imageCount: NSTextField!
    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var nameTextfield: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var backButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        guard let path = self.path else {  fatalError() }
        let urlState = URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent("state")
        
        if let state = recoverState(urlState: urlState){
            self.state = state
            print("State loaded")
        }
        updateUI()
        
        let descriptionForState = curry(self.helper.getDescription)(self.fileSearcher)
        let replaceAndNext = curry(self.helper.saveAndNext)(self.state)(self.lineReplacer)
        let saveAndNext = curry(self.helper.saveAndNext)(self.state)(self.fileWriter)
        
        closeButton.rx.tap
            .subscribe({ _ in
                do{
                    let data = try JSONEncoder().encode(self.state)
                    try data.write(to: urlState, options: Data.WritingOptions.atomic)
                    print("Saved!")
                }catch let error {
                    print("Cannot save sate! \(error.localizedDescription)")
                }
                
            }).addDisposableTo(disposeBag)
        
        backButton.rx.tap
            .filter({ self.helper.canGoBack(state: self.state)  })
            .flatMap({ _ -> Observable<ProgramState> in
                let newState = self.helper.rewind(state: self.state)
                return Observable.just(newState)
            }).subscribe({ state in
                self.updateUI()
                self.didRewind = true
                self.nameTextfield.stringValue = descriptionForState(self.state)
            }).addDisposableTo(disposeBag)
        
        nextButton.rx.tap
            .filter({ !self.nameTextfield.stringValue.isEmpty })
            .map({ self.helper.getImageName(state: self.state) })
            .flatMap({ name -> Observable<Helper.NewState<Data,()>> in
                let line:Helper.Line = (key:name,value:self.nameTextfield.stringValue)
                let value = self.helper.transform(line)
                let state:Helper.NewState<Data,()>
                if self.didRewind {
                    state = replaceAndNext(value)
                }else{
                    state = saveAndNext(value)
                }
                return Observable.just(state)
            }).subscribe({ state in
                // set new states
                if let element = state.element {
                    self.state = element.0
                    self.fileWriter = element.1
                }
                self.updateUI()
                self.didRewind = false
            }).addDisposableTo(disposeBag)
        
    }
    
    func updateUI(){
        self.imageCount.stringValue = helper.imageCountLabel § state
        self.imageView.image = helper.getImage § state
        self.nameTextfield.stringValue = ""
    }
    
    
    func recoverState(urlState:URL) -> ProgramState?{
        do{
            let data = try Data(contentsOf: urlState)
            let recover = try JSONDecoder().decode(ProgramState.self, from: data)
            return recover
        }catch let error {
            print("Cannot recover sate! \(error.localizedDescription)")
        }
        return nil
    }
    
    
}
