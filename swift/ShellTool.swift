//
//  ShellTool.swift
//  ShellTool
//
//  Created by Beiqi on 2021/3/12.
//

import Foundation

let RootDirKey = "rootDir"
let OutputDirKey = "outputDir"
let LanguageKey = "lproj"
let TranslatedDirKey = "translatedDir"

let ActionKey = "1"
enum ActionValue: String, CaseIterable {
    case checkUniqueLocalizedKey
    case replaceLocalizedString
    case collectLocalizedString
    case collectCodeString
    case makeCodeLocalized
}

public func printShellHelp() {
    print("""
usage: {action} # \(ActionValue.allCases.map({ $0.rawValue }).joined(separator: " | "))
    [--\(RootDirKey) value]  # default value = current cmd directory, support short key
    [--\(OutputDirKey) value]  # default value = rootDir.parent directory, support short key
    [--\(LanguageKey) value]  # default value will be all languages in \(RootDirKey), support short key
    [--\(TranslatedDirKey)] value  # translated file will be all contents in this dir. support short key, required for \(ActionValue.replaceLocalizedString.rawValue) action, otherwise will be ignored.
""")
}

public func runShell() {
    let cmdParams = CommandLine.allParams
    guard !cmdParams.isEmpty,
          let action = cmdParams.paramValue(forKey: ActionKey),
          let actV = ActionValue(rawValue: action) else { return printShellHelp() }
    let rootDir = cmdParams.paramValue(forKey:RootDirKey)?.cmdFullPath ?? "".cmdFullPath
    let parentDir = rootDir.parentDirectory
    let outputDir = cmdParams.paramValue(forKey:OutputDirKey)?.fullPath(parent: parentDir) ?? parentDir
    let language = cmdParams.paramValue(forKey:LanguageKey)
    let langsBlk: ()->[String] = {
        if let tmp = language { return [tmp] }
        else { return findAllLanguages(at: rootDir) }
    }
    
    print("==== working path: " + rootDir)

    switch actV {
    case .checkUniqueLocalizedKey:
        checkUniqueLocalizedStrings(rootDir: rootDir, outDir: outputDir, languages: langsBlk())
        
    case .replaceLocalizedString:
        guard let transDir = cmdParams.paramValue(forKey: TranslatedDirKey)?.fullPath(parent: parentDir) else {
            print("---- need \(TranslatedDirKey) ----")
            return
        }
        replaceLocalizedStrings(rootDir: rootDir, languages: langsBlk(), transDir: transDir)

    case .collectLocalizedString:
        collectLocalizedStrings(rootDir: rootDir, outDir: outputDir, languages: langsBlk())
        
    case .collectCodeString:
        collectCodeStrings(rootDir: rootDir, outDir: outputDir)
        
    case .makeCodeLocalized:
        makeCodeLocalized(rootDir: rootDir)
    }
}


public func checkUniqueLocalizedStrings(rootDir: String, outDir: String, languages: [String]) {
    for lang in languages {
        print("--- \(lang) ---")
        var all = Set<String>()
        let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
            let dic = content.filterLocalizedStringKeyValues(fileName: path.fileName)
            all.formUnion(dic.values)
            if dic.isEmpty { print("not found key in \(path)")}
        }
        
        filter.fill(files: ["strings"].hasExts)
            .fill(dirs: [lang + ".lproj"].equalNames)
            .ignoreNotCodeDirs()
            .startToEnumerate(atPath: rootDir)
    }
}



public func replaceLocalizedStrings(rootDir: String, languages: [String], transDir: String) {
    for lang in languages {
        print("--- \(lang) ---")
        let transFile = transDir.appendingFileName("all_strings_\(lang).txt")
        do {
            let tContents = try String(contentsOfFile: transFile, encoding: .utf8)
            let tDic = tContents.filterLocalizedStringKeyValues(fileName: transFile.fileName)
            let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
                guard var tmp = content.isEmpty ? nil : content else { return }
                tmp.filterLocalizedStrings(fileName: path.fileName, replaceBy: tDic)
                guard tmp != content else { return }
                tmp.write(to: path)
            }
            filter.fill(files: ["strings"].hasExts)
                .fill(dirs: [lang + ".lproj"].equalNames)
                .ignoreNotCodeDirs()
                .startToEnumerate(atPath: rootDir)
        } catch {
            print("can not read translated file: \(transFile)")
        }
    }
}



public func collectLocalizedStrings(rootDir: String, outDir: String, languages: [String]) {
    for lang in languages {
        print("--- \(lang) ---")
        var all = Set<String>()
        let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
            let dic = content.filterLocalizedStringKeyValues(fileName: path.fileName)
            all.formUnion(dic.values)
            if dic.isEmpty { print("not found key in \(path)")}
        }

        filter.fill(files: ["strings"].hasExts)
            .fill(dirs: [lang + ".lproj"].equalNames)
            .ignoreNotCodeDirs()
            .startToEnumerate(atPath: rootDir)
        
        let path = outDir.appendingFileName("all_strings_\(lang).txt")
        let kvs = all.sorted().map { ($0, $0) }
        Dictionary(uniqueKeysWithValues: kvs).localizedStrings.write(to: path)
    }
}




public func collectCodeStrings(rootDir: String, outDir: String) {
    var allKeys = Set<String>()
    let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
        let strs = content.filterLocalizedStrings(fileName: path.fileName)
        allKeys.formUnion(strs)
    }
    
    filter.fill(files: ["swift"].hasExts)
        .ignore(dirs: ["lproj"].hasExts)
        .ignoreNotCodeDirs()
        .startToEnumerate(atPath: rootDir)
    
    let path = outDir.appendingFileName("code_string_all_keys.txt")
    allKeys.sorted().joined(separator: "\n").write(to: path)
    let notAsciis = allKeys.filter { !$0.isASCIIstring }
    let head = notAsciis.filter { $0.contains("\\(") }
    let body = notAsciis.subtracting(head)
    let path2 = outDir.appendingFileName("code_string_notASCII_keys.txt")
    let strings = (head.sorted() + body.sorted()).map { "\"\($0)\" = \"\($0)\";" }.joined(separator: "\n\n")
    strings.write(to: path2)
}

public func makeCodeLocalized(rootDir: String) {
    let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
        var ct = content
        guard ct.makeCodeLocalized(fileName: path.fileName) else { return }
        ct.write(to: path)
    }
    
    filter.fill(files: ["swift"].hasExts)
        .ignore(dirs: ["lproj"].hasExts)
        .ignoreNotCodeDirs()
        .startToEnumerate(atPath: rootDir)
}

func test(rootDir: String) {
    let filter = FileIteratorWrapper(rootPath: rootDir) { (path, content) in
        print(path)        
    }

    filter.fill(files: ["strings"].hasExts)
        .fill(dirs: ["lproj"].hasExts)
        .ignoreNotCodeDirs()
        .startToEnumerate(atPath: rootDir)
}
