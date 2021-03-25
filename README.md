# LocalizedString
Swift脚本，需要多个文件联编使用。

cd xxx 当前swift目录
cat *.swift | swiftc -o ../BQStringTool -

usage: {action} # checkUniqueLocalizedKey | replaceLocalizedString | collectLocalizedString | collectCodeString | makeCodeLocalized

    [--rootDir value]  # default value = current cmd directory, support short key

    [--outputDir value]  # default value = rootDir.parent directory, support short key
    
    [--lproj value]  # default value will be all languages in rootDir, support short key
    
    [--translatedDir] value  # translated file will be all contents in this dir. support short key, required for replaceLocalizedString action, otherwise will be ignored.

1. 遍历文件（自定义筛选条件）；
2. 搜集文件中的字符串，合并后输出到文件；
3. 翻译文本替换更新；
