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
    
    lazy var fileSearcher:FileIO<String,String?> = {
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
        
        
        let descriptionForState = curry(self.helper.getDescription)(self.fileSearcher)
        let replaceAndNext = curry(self.helper.saveAndNext)(self.state)(self.lineReplacer)
        let saveAndNext = curry(self.helper.saveAndNext)(self.state)(self.fileWriter)
        
        updateUI(descriptionForState)
        
        closeButton.rx.tap
            .subscribe({ _ in
                do{
                    let data = try JSONEncoder().encode(self.state)
                    try data.write(to: urlState, options: Data.WritingOptions.atomic)
                    print("Saved!")
                    self.view.window?.close()
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
                if let element = state.element {
                    self.state = element
                }
                self.updateUI(descriptionForState)
            }).addDisposableTo(disposeBag)
        
        nextButton.rx.tap
            .filter({ !self.nameTextfield.stringValue.isEmpty })
            .map({ self.helper.getImageName(state: self.state) })
            .flatMap({ name -> Observable<Helper.NewState<Data,()>> in
                let line:Helper.Line = (key:name,value:self.nameTextfield.stringValue)
                let value = self.helper.transform(line)
                let state:Helper.NewState<Data,()>
                if descriptionForState(self.state) != nil {
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
                self.updateUI(descriptionForState)
                
            }).addDisposableTo(disposeBag)
        
    }
    
    func updateUI(_ descriptFn:(ProgramState)->String?){
        self.imageCount.stringValue = helper.imageCountLabel § state
        self.imageView.image = helper.getImage § state
        self.nameTextfield.stringValue = descriptFn(self.state) ?? ""
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
