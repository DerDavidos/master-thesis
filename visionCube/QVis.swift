import Foundation

struct QVisFileException: Error {
    var message: String
}

struct QVisDatLine {
    var id: String
    var value: String
    
    init(_ input: String) {
        if let found = input.firstIndex(of: ":") {
            id = String(input[..<found])
            value = String(input[input.index(after: found)...])
            id = id.trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: .whitespaces)
            id = id.lowercased()
            value = value.lowercased()
        } else {
            id = ""
            value = ""
        }
    }
    
    private func ltrim(_ s: inout String) {
        s = String(s.drop(while: { $0.isWhitespace }))
    }
    
    private func rtrim(_ s: inout String) {
        if let lastNonWhitespaceIndex = s.lastIndex(where: { !$0.isWhitespace }) {
            s.removeSubrange(lastNonWhitespaceIndex..<s.endIndex)
        }
    }
    
    private func trim(_ s: inout String) {
        ltrim(&s)
        rtrim(&s)
    }
}

class QVis {
    var volume: Volume
    
    init(filename: String) throws {
        self.volume = Volume()
        try load(filename: filename)
    }
    
    fileprivate func convert16to8Bit(_ rawFile: Data) -> [UInt8]{
        let data16Bit = rawFile.withUnsafeBytes { rawBufferPointer -> [UInt16] in
            let bufferPointer = rawBufferPointer.bindMemory(to: UInt16.self)
            return Array(bufferPointer)
        }
        
        var minVal = data16Bit[0]
        var maxVal = data16Bit[0]
        for val in data16Bit {
            minVal = min(minVal, val)
            maxVal = max(maxVal, val)
        }
        
        var data: [UInt8] = Array()
        for i in 0..<data16Bit.count {
            let tmp = 255 * (UInt(data16Bit[i] - minVal))
            let normalizedValue = tmp / (UInt(maxVal - minVal) + 1)
            
            data.append(UInt8(normalizedValue))
        }
        return data
    }
    
    fileprivate func readDataFile(_ lines: [String], _ p: URL, _ rawFilename: inout String, _ needsConversion: inout Bool) throws {
        for line in lines {
            let l = QVisDatLine(line)
            if l.id == "objectfilename" {
                if p.deletingLastPathComponent().path.isEmpty {
                    rawFilename = l.value
                } else {
                    rawFilename = p.deletingLastPathComponent().path + "/" + l.value
                }
            } else if l.id == "resolution" {
                let t = l.value.components(separatedBy: " ")
                if t.count != 3 {
                    throw QVisFileException(message: "invalid resolution tag")
                }
                guard let width = UInt(t[0]), let height = UInt(t[1]), let depth = UInt(t[2]) else {
                    throw QVisFileException(message: "invalid resolution tag")
                }
                volume.width = width
                volume.height = height
                volume.depth = depth
                volume.maxSize = max(width, max(height, depth))
            } else if l.id == "format" {
                if l.value != "char" && l.value != "uchar" && l.value != "byte" {
                    needsConversion = true
                }
            } else if l.id == "endianess" {
                if l.value != "little" {
                    throw QVisFileException(message: "only little endian data supported by this mini-reader")
                }
            }
        }
    }
    
    func load(filename: String) throws {
        guard let datfile = FileManager.default.contents(atPath: filename) else {
            throw QVisFileException(message: "Unable to read file \(filename)")
        }
        
        var needsConversion: Bool = false
        let p = URL(fileURLWithPath: filename)
        var rawFilename = ""
        
        if let lines = String(data: datfile, encoding: .utf8)?.components(separatedBy: .newlines) {
            try readDataFile(lines, p, &rawFilename, &needsConversion)
        }
        
        if rawFilename.isEmpty {
            throw QVisFileException(message: "object filename not found")
        }
        
        let rawFile = try Data(contentsOf: URL(fileURLWithPath: rawFilename))
        
        if needsConversion {
            volume.data = convert16to8Bit(rawFile)
        } else {
            volume.data = [UInt8](rawFile)
        }
    }
    
    func tokenize(_ str: String) -> [String] {
        return str.components(separatedBy: " ")
    }
}

func getFromResource(strFileName: String, ext: String) -> String {
    guard let cfFilename = CFStringCreateWithCString(kCFAllocatorDefault, strFileName, CFStringGetSystemEncoding()) else {
        return ""
    }
    
    guard let cfExt = CFStringCreateWithCString(kCFAllocatorDefault, ext, CFStringGetSystemEncoding()) else {
        return ""
    }
    
    guard let imageURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), cfFilename, cfExt, nil) else {
        return ""
    }
    
    let macPath = CFURLCopyFileSystemPath(imageURL, CFURLPathStyle.cfurlposixPathStyle)
    let pathPtr = CFStringGetCStringPtr(macPath, CFStringGetSystemEncoding())
    
    if let pathPtr = pathPtr, let result = String(validatingUTF8: pathPtr) {
        return result
    } else {
        return ""
    }
}
