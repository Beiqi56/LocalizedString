//
//  CommandLine+Tool.swift
//  TestTool
//
//  Created by Beiqi xu on 2019/12/1.
//  Copyright © 2019 Beiqi xu. All rights reserved.
//

import Foundation


public extension String {
    var cmdFullPath: String {
        guard !hasPrefix("/") else { return self }
        return FileManager.default.currentDirectoryPath.appendingFileName(self)
    }
    func fullPath(parent: String) -> String {
        guard !hasPrefix("/") else { return self }
        return parent.appendingFileName(self)
    }
}

public extension CommandLine {
    
    fileprivate enum Param {
        case path(String), shortKey(String), longKey(String), other(String)
    }
    
    // [key|index :  value]
    static var allParams: [String: String] {
        return analyzeArguments(arguments)
    }
    
    static func analyzeArguments(_ array: [String]) -> [String: String] {
        var allParam = [Param]()
        for str in array {
            var tmpParam: Param
            if str.hasPrefix("/") || str.hasPrefix("./") || str.hasPrefix("../") {
                tmpParam = .path(str)
            } else if str.hasPrefix("--") {
                let v = str.suffix(from: str.index(str.startIndex, offsetBy: 2))
                tmpParam = .longKey(String(v))
            } else if str.hasPrefix("-") {
                let v = str.suffix(from: str.index(after: str.startIndex))
                tmpParam = .shortKey(String(v))
            } else {
                tmpParam = .other(str)
            }
            allParam.append(tmpParam)
        }
        
        return analyzeParam(allParam)
    }
    
    private static func analyzeParam(_ array: [Param]) -> [String : String] {
        var result = [String:String]()
        var idx = 0
        var paramIndex = 0
        while idx < array.count {
            switch array[idx] {
            case .path(let x):
                result["\(paramIndex)"] = x; paramIndex += 1
            case .shortKey(let x):
                if x.count > 1 {
                    for c in x { result["\(c)"] = "" }
                } else if idx+1 < array.count {
                    switch array[idx+1] {
                    case .path(let v):
                        result[x] = v;  idx += 1
                    case .other(let v):
                        result[x] = v; idx += 1
                    default: result[x] = ""
                    }
                }
            case .longKey(let x):
                let value = idx+1 < array.count ? array[idx+1] : .other("")
                switch value {
                case .path(let v):
                    result[x] = v;  idx += 1
                case .other(let v):
                    result[x] = v; idx += 1
                default: result[x] = ""
                }
            case .other(let x):
                result["\(paramIndex)"] = x; paramIndex += 1
            }
            idx += 1
        }

        return result
    }
    
}


public extension Dictionary where Key == String, Value == String {
    func paramValue(forKey k: String) -> String? {
        if let v = self[k] { return v }
        guard k.count > 1 else { return nil }
        return self[String(k.first!)]
    }
}
