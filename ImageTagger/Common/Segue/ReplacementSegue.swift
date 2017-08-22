//
//  ReplacementSegue.swift
//  ImageTagger
//
//  Created by Alcala, Jose Luis on 8/20/17.
//  Copyright © 2017 Alcala, Jose Luis. All rights reserved.
//

import Cocoa

class ReplacementSegue: NSStoryboardSegue {

    override func perform() {
        guard let from = sourceController as? NSViewController,
              let to = destinationController as? NSViewController
             else { return; }
        
        from.view.window?.contentViewController = to
    }
    
    
}
