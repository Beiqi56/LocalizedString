//
//  String+File.swift
//  TestTool
//
//  Created by Beiqi xu on 2021/3/11.
//  Copyright © 2021 Beiqi xu. All rights reserved.
//

import Foundation

public extension String {
    
    var lastPathComponent_bq: String {
        (self as NSString).lastPathComponent
    }
    var deletingLastPathComponent_bq: String {
        (self as NSString).deletingLastPathComponent
    }
    var pathExtension_bq: String {
        (self as NSString).pathExtension
    }
    func appendingPathComponent_bq(_ name: String) -> String {
        (self as NSString).appendingPathComponent(name)
    }
    
    
    
    var fileExt: String { pathExtension_bq }
    var fileName: String { lastPathComponent_bq }
    var parentFileName: String { deletingLastPathComponent_bq.fileName }
    var parentDirectory: String { deletingLastPathComponent_bq }
    func appendingFileName(_ name: String) -> String { appendingPathComponent_bq(name) }
    var withoutExt: String {
        guard let idx = lastIndex(of: ".") else { return self }
        return String(self[..<idx])
    }
}



public extension String {
    var isASCIIstring: Bool {
        for c in self {
            if !c.isASCII { return false }
        }
        return true
    }
    
    func write(to path: String) {
        do {
            try write(toFile: path, atomically: true, encoding: .utf8)
            print(" >>>> saved file \(utf8.count.bytesSize) : \t" + path)
        } catch {
            print(" ~~~~ failed to save file" + path)
            print(" \(error)")
        }
    }
}


public extension Int {
    var bytesSize: String {
        if      self < (1<<10) { return "\(ceil(shiftR: 0))B" }
        else if self < (1<<20) { return "\(ceil(shiftR:10))K" }
        else if self < (1<<30) { return "\(ceil(shiftR:20))M" }
        else                   { return "\(ceil(shiftR:30))G" }
    }
    private func ceil(shiftR bitmask: Int) -> Int {
        guard bitmask > 0 else { return self }
        return ((self >> (bitmask-1)) + 1) >> 1
    }
}
