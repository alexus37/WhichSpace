//
//  StatusItemView.swift
//  WhichSpace
//
//  Created by Stephen Sykes on 30/10/15.
//  Copyright © 2020 George Christou. All rights reserved.
//

import Cocoa

class StatusItemCell: NSStatusBarButtonCell {
    
    var isMenuVisible = false
    
    override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {

        let darkColor = NSColor(
            calibratedWhite: AppDelegate.darkModeEnabled ? 0.7 : 0.0,
            alpha: 0.0
        )
        let whiteColor = NSColor(
            calibratedWhite: AppDelegate.darkModeEnabled ? 0 : 1,
            alpha: 0.0
        )

        let foregroundColor = isMenuVisible ? darkColor : whiteColor
        
        let titleRect = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height
        )
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        
        let attributes = [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.foregroundColor: foregroundColor
        ]
        title.draw(in: titleRect, withAttributes: attributes)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
