//
//  extensions.swift
//  FaceMouse
//
//  Created by Ferdinand Lösch on 18.06.18.
//  Copyright © 2018 Ferdinand Lösch. All rights reserved.
//

import Foundation

import UIKit


extension Array where Element: Numeric {
    /// Returns the total sum of all elements in the array
    var total: Element { return reduce(0, +) }

   
}

extension Array where Element: BinaryInteger {
    /// Returns the average of all elements in the array
    var average: Double {
        return isEmpty ? 0 : Double(Int(total)) / Double(count)
    }
}

extension Array where Element: FloatingPoint {
    /// Returns the average of all elements in the array
    var average: Element {
        return isEmpty ? 0 : total / Element(count)
    }
}


extension CGPoint {
    func getRandom(rect: CGRect)-> CGPoint {
        func random(min: Int, _ max: Int) -> Int {
            guard min < max else {return min}
            return Int(arc4random_uniform(UInt32(1 + max - min))) + min
        }
        let x = random(min: Int(rect.minX + 40) , Int(rect.maxX - 40))
        let y = random(min: Int(rect.minY + 100) , Int(rect.maxY - 40))
        return CGPoint(x: x, y: y)
    }
}


func getSpeed() -> Int {
    if let session = UserDefaults.standard.value(forKey: "Speed") as? Int {
        return session
    } else {
        return 40
    }
}

func getSensitivity() -> Float {
    if let session = UserDefaults.standard.value(forKey: "sensitivity") as? Float {
        return session
    } else {
        return 4
    }
}

func getSelection() -> Int {
    if let session = UserDefaults.standard.value(forKey: "selection") as? Int {
        return session
    } else {
        return 0
    }
}


