//
//  FileFinder.swift
//  TestTool
//
//  Created by Beiqi xu on 2019/12/1.
//  Copyright © 2019 Beiqi xu. All rights reserved.
//

import Foundation


public typealias FileIterator = (_ enumerator: FileManager.DirectoryEnumerator, _ currentItem: String, _ isDir: Bool) -> Void

public struct FileIteratorWrapper {
    public var iterator: FileIterator
}


public extension FileIteratorWrapper {
    
    typealias ConditionBlk = (_ file: String) -> Bool
    
    func fill(dirs: @escaping ConditionBlk) -> Self {
        Self { (it, file, isDir) in
            if isDir {
                if dirs(file) { iterator(it, file, isDir) }
            } else {
                let tmp = file.parentDirectory
                if !tmp.isEmpty, dirs(tmp) { iterator(it, file, isDir) }
            }
        }
    }
    
    func ignore(dirs: @escaping ConditionBlk) -> Self {
        Self { (it, file, isDir) in
            if isDir && dirs(file) { it.skipDescendents() }
            else { iterator(it, file, isDir) }
        }
    }
    
    func fill(files: @escaping ConditionBlk) -> Self {
        Self { (it, file, isDir) in
            guard isDir || files(file) else { return }
            iterator(it, file, isDir)
        }
    }
    

    init(rootPath: String, processText: @escaping (_ fullPath: String, _ content: String)->Void ) {
        self.init { (em, item, isDir) in
            guard !isDir else { return }
            let fullPath = rootPath.appendingFileName(item)
            do {
                let ct = try String(contentsOfFile: fullPath, encoding: .utf8) 
                processText(fullPath, ct)
            } catch {
                print("failed to read contents of file \(item)")
                print(error)
            }
        }
    }
    
    func startToEnumerate(atPath path: String) {
        FileManager.default.findFilesRecursively(atPath: path, operation: iterator)
    }
    
}

public extension Array where Element == String {
    var hasExts: FileIteratorWrapper.ConditionBlk {
        if count == 1 { 
            let sfx = "." + first!
            return { $0.hasSuffix(sfx) }
        } else {
            let set = Set(self)
            return { set.contains($0.fileExt) }
        }
    }
    
    var equalNames: FileIteratorWrapper.ConditionBlk {
        if count == 1 {
            let name = first!
            return { $0.fileName == name }
        } else {
            let set = Set(self)
            return { set.contains($0.fileName) }
        }
    }

}

public let  IgnoreAll:FileIteratorWrapper.ConditionBlk = { _ in false }

public extension FileManager {

    func findFilesRecursively(atPath path0: String,  operation:FileIterator) {
        let path = path0.trimmingCharacters(in: .whitespacesAndNewlines)
        print(" -------- start finding files -------- ")
        defer { print(" -------- end finding files -------- ") }
        guard let enumerator = enumerator(atPath: path) else {
            print("can not find path : \(path)"); return
        }
        
        while let item = enumerator.nextObject() as? String {
            let isDir = (enumerator.fileAttributes?[.type] as? FileAttributeType) == .typeDirectory
            operation(enumerator, item, isDir)
        }
    }
    
    func createDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        if fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue { return true }
        var created = true
        do {
            try createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("failed to create path: \(path)")
            print("\(error)")
            created = false
        }
        return created
    }
}


func testDirs() {
    let root = "/Users/beiqi/Documents/Project_Job/iOS/Wishwork/sendabox/SendaBox/SendaBox/Me"
    let itWrapper = FileIteratorWrapper { (enm, item, isDir) in
        print(item + (isDir ? "  --" : ""))
    }
    itWrapper.fill(dirs: { $0.hasSuffix(".lproj") }).startToEnumerate(atPath: root)
    print(findAllLanguages(at:root))
}


func findAllNames(forDirExts exts: [String], at root: String, moreOp:( (FileIteratorWrapper)->FileIteratorWrapper)? = nil) -> Set<String> {
    var allNames = Set<String>()
    let itWrapper = FileIteratorWrapper {[] (enm, item, isDir) in
        allNames.insert(item.fileName.withoutExt)
        enm.skipDescendents()
    }
    
    (moreOp?(itWrapper) ?? itWrapper)
        .fill(dirs: exts.hasExts)
        .fill(files: IgnoreAll)
        .startToEnumerate(atPath: root)
    return allNames
}

func findAllLanguages(at root: String) -> [String] {
    var set = findAllNames(forDirExts: ["lproj"], at: root) { 
        $0.ignoreNotCodeDirs()
    }
    set.remove("Base")
    return Array(set)
}



public extension FileIteratorWrapper {
    func ignoreNotCodeDirs() -> Self {
        ignore(dirs: ["xcassets", "framework", "bundle"].hasExts)
    }
}
