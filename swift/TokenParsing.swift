//#!/usr/bin/swift
//
//  Sentence.swift
//  TestTool
//
//  Created by Beiqi xu on 2019/11/26.
//  Copyright © 2019 Beiqi xu. All rights reserved.
//

import Foundation

public enum ParsingState {
    case missed, matching, matched
    case rollback (String.Index)
}

extension ParsingState: Equatable {
    public static func == (lhs: ParsingState, rhs: ParsingState) -> Bool {
        switch (lhs, rhs) {
        case (.missed, .missed), (.matching, .matching), (.matched, .matched):
            return true
        case (.rollback(let a), .rollback(let b)): 
            return a == b
        default:
            return false
        }
    }
}
    


public class LexicalCursor {
    var src:        String
    var crtIdx:     String.Index
    var crtChar:    Character?
    
    init(_ str: String) {
        src = str
        crtIdx = str.startIndex
        crtChar = str.first
    }
    
    var isEnd: Bool { crtIdx  == src.endIndex }
    
    @discardableResult
    func moveNext() -> Bool {
        guard !isEnd else { return false }
        crtIdx = src.index(after: crtIdx)
        crtChar = isEnd ? nil : src[crtIdx]
        return true
    }
    
    func move(to: String.Index) {
        crtIdx = to
        crtChar = isEnd ? nil : src[to]
    }
}




public protocol LexicalParsing: class {
    var copied: LexicalParsing { get }
    var tagId: Int { get }
    var currentState: ParsingState  { get }
    func matchedResult(at: String) -> String?
    func parse(_ c: Character, ofIndex: String.Index) -> ParsingState
    func parse(andMove cursor: LexicalCursor) -> ParsingState
    func reset()
}

public extension LexicalParsing {
    var tagId: Int { 0 }
    
    // will consume cursor, while matching, or matched
    func parse(andMove cursor: LexicalCursor) -> ParsingState {
        guard !cursor.isEnd else { return currentState }
        let st = parse(cursor.crtChar!, ofIndex: cursor.crtIdx)
        switch st {
        case .matched:
            cursor.moveNext()
            return .matched
            
        case .matching: 
            cursor.moveNext()
            return parse(andMove: cursor)

        default:
            return st
        }
    }
}


public extension LexicalCursor {
    
    // return matched.
    func startParsing(nodes: [LexicalParsing]) -> (matched: [LexicalParsing], matching: LexicalParsing?) {
        var allMatched = [LexicalParsing]()

        OutLoop:  while !isEnd {
            // one loop begin
            for (idx, nd) in nodes.enumerated() {
                switch nd.parse(andMove: self) {
                case .matched:
                    allMatched.append(nd.copied)
                    nd.reset()
                    continue OutLoop
                    
                case .matching:
                    if !isEnd { assert(false, "should never happend") }
                    continue OutLoop
                    
                case .rollback(let strIdx):
                    if let matched = recallParsing(backTo: strIdx, nodes: nodes.suffix(from: idx+1)) {
                        allMatched.append(matched)
                    }
                    continue OutLoop

                case .missed:
                    continue
                }
            } // one loop end
            moveNext()
        }
        return (allMatched, nodes.first(where: { $0.currentState == .matching }))
    }
    
    private func recallParsing(backTo org: String.Index, nodes: ArraySlice<LexicalParsing>) -> LexicalParsing? {
        guard org < crtIdx, !nodes.isEmpty else { return nil }
        move(to: org)

        for (idx, nd) in nodes.enumerated() {
            switch nd.parse(andMove: self) {
            case .matched:
                let cp = nd.copied
                nd.reset()
                return cp
                
            case .matching:
                if !isEnd { assert(false, "should never happend") }
                return nil
                
            case .rollback(let strIdx):
                let subnodes = nodes.suffix(from: idx+1+nodes.startIndex)
                return recallParsing(backTo: strIdx, nodes: subnodes)
                
            case .missed:
                continue
            }
        }
        
        moveNext()
        return nil
    }
}


public class TokenParsing : LexicalParsing {

    private let token: [Character]
    private var index: Int = 0
    private(set) var strBegin: String.Index?
    
    init(_ str: String) {
        token = Array(str)
    }
    init(_ tk: TokenParsing) {
        token = tk.token
        index = tk.index
        strBegin = tk.strBegin
    }

    func strEnd(at: String) -> String.Index? {
        guard currentState == .matched else { return nil }
        return at.index(strBegin!, offsetBy: token.count)
    }
    
    public var copied: LexicalParsing { TokenParsing(self) }
    
    public var currentState: ParsingState {
        guard strBegin != nil else { return .missed }
        return index < token.count ? .matching : .matched
    }
    
    public func matchedResult(at: String) -> String? {
        return currentState == .matched ? String(token) : nil
    }
    
    public func reset() {
        index = 0
        strBegin = nil
    }

    public func parse(_ c: Character, ofIndex: String.Index) -> ParsingState {
        switch currentState {
        case .missed:
            if token[index] == c {
                index += 1
                strBegin = ofIndex
            } else {
                return .missed
            }
            
        case .matching:
            if token[index] == c {
                index += 1
            } else {
                let st = ParsingState.rollback(strBegin!)
                reset()
                return st
            }

        default: break
        }
        return currentState
    }

}

public class BackslashTokenParsing : LexicalParsing {
    
    private(set) var strBegin: String.Index?
    private var valueIndex: String.Index?
    private var bracketBegin: String.Index?
    private var bracketEnd: String.Index?
    
    init() { }
    
    init(_ tmp: BackslashTokenParsing) {
        self.strBegin = tmp.strBegin
        self.valueIndex = tmp.valueIndex
        self.bracketBegin = tmp.bracketBegin
        self.bracketEnd = tmp.bracketEnd
    }
    
    public var copied: LexicalParsing { BackslashTokenParsing(self) }
    
    public var currentState: ParsingState {
        if valueIndex != nil || bracketEnd != nil { return .matched }
        else if strBegin != nil { return .matching }
        else { return .missed }
    }
    
    public func matchedResult(at: String) -> String? {
        guard currentState == .matched else { return nil }
        return String(at[strBegin!...(valueIndex ?? bracketEnd!)])
    }
    
    public func reset() {
        strBegin = nil
        valueIndex = nil
        bracketBegin = nil
        bracketEnd = nil
    }
    
    public func parse(_ c: Character, ofIndex: String.Index) -> ParsingState {
        switch currentState {
        case .missed:
            if c == "\\" {
                strBegin = ofIndex
            }
            
        case .matching:
            if bracketBegin == nil {
                if c == "(" {
                    bracketBegin = ofIndex
                } else {
                    valueIndex = ofIndex
                }
            } else if c == ")" {
                bracketEnd = ofIndex
            }
            
        default:
            break
        }
        return currentState
    }

}


public class PairTokenParsing : LexicalParsing {

    let leftToken:  TokenParsing
    let rightToken: TokenParsing
    let backslashToken: BackslashTokenParsing?
    public let tagId: Int
    
    init(_ tmp: PairTokenParsing) {
        leftToken = tmp.leftToken.copied as! TokenParsing
        rightToken = tmp.rightToken.copied as! TokenParsing
        backslashToken = tmp.backslashToken?.copied as? BackslashTokenParsing
        tagId = tmp.tagId
    }

    init(_ left: String, _ right: String, tagId: Int, ignoreBackslash: Bool = false) {
        leftToken = TokenParsing(left)
        rightToken = TokenParsing(right)
        self.tagId = tagId
        backslashToken = ignoreBackslash ? nil : BackslashTokenParsing()
    }
    
    public var currentState: ParsingState {
        let lSt = leftToken.currentState
        guard lSt == .matched else { return lSt }
        let rSt = rightToken.currentState
        return rSt == .missed ? .matching : rSt
    }
    
    func content(for str: String, containsToken: Bool = false) -> String? {
        guard currentState == .matched else { return nil }
        let ct = str[leftToken.strEnd(at: str)! ..< rightToken.strBegin!]
        guard containsToken else { return String(ct) }
        return leftToken.matchedResult(at: str)! + ct + rightToken.matchedResult(at: str)!
    }

    func range(for str: String, containsToken: Bool = false) -> Range<Int>? {
        guard currentState == .matched else { return nil }
        let rg = containsToken ? 
            leftToken.strBegin! ..< rightToken.strEnd(at: str)! :
            leftToken.strEnd(at: str)! ..< rightToken.strBegin!
        return rg.lowerBound.utf16Offset(in: str) ..< rg.upperBound.utf16Offset(in: str)        
    }
    
    func unlocalizedRange(for str: String) -> Range<Int>? {
        guard currentState == .matched else { return nil }
        let rg = leftToken.strBegin! ..< rightToken.strEnd(at: str)!
        if str[rg.upperBound...].hasPrefix(".localized") { return nil }
        return rg.lowerBound.utf16Offset(in: str) ..< rg.upperBound.utf16Offset(in: str)        
    }

    public var copied: LexicalParsing {
        PairTokenParsing(self)
    }
    
    public func matchedResult(at: String) -> String? {
        content(for: at, containsToken: true)
    }
    
    public func reset() {
        leftToken.reset()
        rightToken.reset()
        backslashToken?.reset()
    }

    public func parse(_ c: Character, ofIndex: String.Index) -> ParsingState {
        guard leftToken.currentState == .matched else { 
            let st = leftToken.parse(c, ofIndex: ofIndex)
            return st == .matched ? .matching : st
        }
        
        if let bs = backslashToken {
            switch bs.parse(c, ofIndex: ofIndex) {
            case .matched: bs.reset(); return .matching
            case .matching: return .matching
            case .missed:  break
            case .rollback(_): break // never happend
            }
        }
        
        let st = rightToken.parse(c, ofIndex: ofIndex)
        switch st {
        case .matched:            return .matched
        case .matching, .missed:  return .matching
        case .rollback(_):  rightToken.reset(); return st
        }
    }
    
    // will consume cursor, while matching, or matched
    public func parse(andMove cursor: LexicalCursor) -> ParsingState {
        guard !cursor.isEnd else { return currentState }
        let st = parse(cursor.crtChar!, ofIndex: cursor.crtIdx)
        switch st {
        case .matched:
            cursor.moveNext()
            return .matched
        case .matching:
            cursor.moveNext()
            return parse(andMove: cursor)
        case .missed:
            return st
        case .rollback(let org):
            guard leftToken.currentState == .matched else {
                return st
            }
            cursor.move(to: org); cursor.moveNext()
            return parse(andMove: cursor)
        }
    }
}


public extension String {
    
    func filterLocalizedStringItems(fileName: String?) -> [PairTokenParsing] {
        let CmtTag  = 1
        let StringTag = 2
        let quote = "\"";

        let cursor = LexicalCursor(self)
        let matchRes = cursor.startParsing(nodes: [
            PairTokenParsing("//", "\n", tagId: CmtTag, ignoreBackslash: true),
            PairTokenParsing("/*", "*/", tagId: CmtTag, ignoreBackslash: true),
            PairTokenParsing(quote, quote, tagId: StringTag, ignoreBackslash: false),
        ])
        let arr = matchRes.matched.filter { $0.tagId == StringTag }
        return arr as! [PairTokenParsing]
    }
    
    func filterLocalizedStrings(fileName: String?) -> [String] {
        var invalids = [String]()
        let res: [String] = filterLocalizedStringItems(fileName: fileName).compactMap {
            if let str = $0.content(for: self) { return str }
            invalids.append("    \($0)  \($0.currentState)")
            return nil
        }
        if let fn = fileName, !invalids.isEmpty {
            print("  --\(fn) invalids: \(invalids)")
        }
        return res
    }
    
    func filterLocalizedStringKeyValues(fileName: String?) -> [String: String] {
        var array = filterLocalizedStrings(fileName: fileName)
        guard !array.isEmpty else { return [:] }
        
        if array.count % 2 != 0 {
            print("odd count = \(array.count)")
            array.append("")
        }

        var dic: [String: String] = [:]
        var rpKeys = Set<String>()
        for idx in stride(from: 0, to: array.count, by: 2) {
            print("index = \(idx)")
            let key =   array[idx]
            let value = array[idx+1]
            if let ov = dic.updateValue(value, forKey: key), ov != value {
                rpKeys.insert(key)
            }
        }
        if let fn = fileName, rpKeys.count > 0 {
            print("  --\(fn) repeat keys: \(rpKeys)")
        }

        return dic
    }
    
    mutating func filterLocalizedStrings(fileName: String?, replaceBy dic: [String : String]) {
        var array = filterLocalizedStringItems(fileName: fileName)
        if array.count % 2 == 1 { array.removeLast() }
        let rgs = array.compactMap { $0.range(for: self, containsToken: false) }
        for index in stride(from: rgs.count-1, to: 0, by: -2) {
            let rg = rgs[index]; let nsrg = NSRange(location: rg.lowerBound, length: rg.upperBound-rg.lowerBound)
            guard let strRg = Range<Index>(nsrg, in: self) else { continue }
            let oldValue = String(self[strRg])
            guard let newValue = dic[oldValue] else { continue }
            replaceSubrange(strRg, with: newValue)
        }
    }
    
    mutating func makeCodeLocalized(fileName: String?) -> Bool {
        let array = filterLocalizedStringItems(fileName: fileName)
        let rgs = array.compactMap { $0.unlocalizedRange(for: self) }
        var changed = false
        for index in stride(from: rgs.count-1, to: 0, by: -1) {
            let rg = rgs[index]; let nsrg = NSRange(location: rg.lowerBound, length: rg.upperBound-rg.lowerBound)
            guard let strRg = Range<Index>(nsrg, in: self) else { continue }
            let oldValue = String(self[strRg])
            guard !oldValue.isASCIIstring else { continue }
            replaceSubrange(strRg, with: oldValue + ".localized")
            changed = true
        }
        return changed
    }

}




public extension Dictionary where Key == String, Value == String {
    var localizedStrings: String {
        map { "\"\($0.key)\" = \"\($0.value)\";" }.joined(separator: "\n\n")
    }
}
