//
//  ViewController.swift
//  ImageTagger
//
//  Created by Alcala, Jose Luis on 8/20/17.
//  Copyright © 2017 Alcala, Jose Luis. All rights reserved.
//

import Cocoa
import RxCocoa
import RxSwift

final class ViewController: NSViewController {

    @IBOutlet weak var pathTextField: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    let disposableBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nextButton.rx.tap
            .map({ self.pathTextField.stringValue })
            .filter(isValidPath)
            .subscribe(goNext)
            .addDisposableTo(disposableBag)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    private func isValidPath(_ path:String) -> Bool {
        
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let fileManager = FileManager.default
        guard !path.isEmpty,url.isFileURL else {
            return false
        }
        
        let files = try! fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        return files.map({ $0.pathExtension }).first(where: { $0 == "jpg" }) != nil
    }
    
    private func goNext(_ path:Event<String>){
        if let path = path.element {
            self.performSegue(withIdentifier: NSStoryboardSegue.Identifier.init(Segues.ImagePath.rawValue), sender: path)
        }
    }
    
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        if segue.identifier?.rawValue == Segues.ImagePath.rawValue,
            let imagVc = segue.destinationController as? ImageViewController{
            imagVc.path = sender as? String
        }
        
    }
    
}

