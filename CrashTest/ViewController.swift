//
//  ViewController.swift
//  CrashTest
//
//  Created by yuanl on 2024/12/2.
//

import UIKit
import RxSwift
import ObjectMapper

class ViewController: UIViewController {
    let disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        Task {
            await callTestConcurrently()
        }
        
        func test() {
            let decoder = JSONDecoder()
            let jsonString = """
                    {"Content":"eyJwbGF5TGlzdCI6eyJzb3J0SWQiOjAsInBsYXlMaXN0SWQiOjY1NTM1LCJtdXNpY051bSI6MSwicGxheUxpc3ROYW1lIjoiQWxsIHNvbmdzIiwibXVzaWNJdGVtcyI6W3sia2V5IjoxNzM0ODA3MjM2fV19fQ=="}
                    """
            let validatedResponseData = jsonString.data(using: .utf8)!
            if let data = try? decoder.decode(NextgenBase64GenericValue<WatchOfflineMusicPlayListDetails>.self, from: validatedResponseData) {
                let obcSingle = Single.create { observer in
                    observer(.success(data.value.playList))
                    return Disposables.create()
                }
                
                obcSingle.map {
                    WatchOfflineMusicConvertUntil.convertToUniversalModelFrom($0)
                }
                .catchAndReturn(OfflineMusicSongListModel())
                .flatMap { [weak self] playList in
                    print("🐶 convert-\(Date().timeIntervalSince1970) \(playList) ")
                    return Single.just(playList)
                }
                .subscribe { rest in
                    print("🐶 convert - item")
                }.disposed(by: disposeBag)
            }
        }
        
        func callTestConcurrently() async {
            await withTaskGroup(of: Void.self) { group in
                for _ in 1...10 {
                    group.addTask {
                        test() // 并发调用 test
                    }
                }
            }
            print("All test calls completed")
        }
    }
    
    
    
    
}

private class WatchOfflineMusicConvertUntil {
    static func convertToUniversalModelFrom(_ watchModel: WatchOfflineMusicPlayList) -> OfflineMusicSongListModel {
        return OfflineMusicSongListModel(sortId: watchModel.sortId.toData(count: 4).toHexString(),
                                         playListId: watchModel.playListId.toData(count: 4).toHexString(),
                                         musicNum: Int(watchModel.musicNum),
                                         playListName: watchModel.playListName,
                                         musicList: watchModel.musicItems?.map { OfflineMusicSongKeyModel(key: $0.key.toData(count: 4).toHexString()) } ?? [],
                                         dataType: .watch)
    }
    
    static func convertToUniversalModelFrom(_ watchModels: [WatchOfflineMusicPlayList]) -> [OfflineMusicSongListModel] {
        return watchModels.map { self.convertToUniversalModelFrom($0) }
    }
    
    static func convertToUniversalModelFrom(_ mediaInfo: WatchOfflineMediaInfo) -> OfflineMusicSongModel {
        let musicInfo = OfflineMusicInfoModel(duration: mediaInfo.duration,
                                              artist: mediaInfo.artist,
                                              album: mediaInfo.album,
                                              title: mediaInfo.title)
        return OfflineMusicSongModel(key: mediaInfo.key.toData(count: 4).toHexString(),
                                     musicInfo: musicInfo,
                                     dataType: .watch)
    }
}

fileprivate struct NextgenGenericValue<T: Codable>: Codable {
    var value: T
    
    enum CodingKeys: String, CodingKey {
        case value = "Content"
    }
}

fileprivate struct NextgenBase64GenericValue<T: Codable>: Codable {
    var value: T
    
    enum CodingKeys: String, CodingKey {
        case value = "Content"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let encodedValue = try container.decode(String.self, forKey: .value)
        guard let decodedData = Data(base64Encoded: encodedValue) else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Content field is not valid Base64")
        }
        
        let decodedValue = try JSONDecoder().decode(T.self, from: decodedData)
        self.value = decodedValue
    }
}

private struct WatchOfflineMusicPlayLists: Codable {
    let playLists: [WatchOfflineMusicPlayList]
}

private struct WatchOfflineMusicPlayListDetails: Codable {
    let playList: WatchOfflineMusicPlayList
}

struct WatchOfflineMusicPlayList: Codable {
    let sortId: UInt16
    let playListId: UInt32
    let musicNum: UInt32
    let playListName: String
    var musicItems: [WatchOfflineMusicItem]?
}

struct WatchOfflineMusicItem: Codable {
    let key: UInt32
}

private struct WatchOfflineMusicContainer: Codable {
    let musicInfo: WatchOfflineMediaInfo
}

struct WatchOfflineMediaInfo: Codable {
    let duration: UInt32
    let artist: String
    let album: String
    let title: String
    
    var key: UInt32 = 0
    var isAdded = false
    
    enum CodingKeys: String, CodingKey {
        case duration
        case artist
        case album
        case title
    }
}

struct WatchOfflineMusicSort: Codable {
    let sortId: UInt16
    let playListId: UInt32
}

enum OfflineMusicDevice: Int, RawRepresentable {
    case earphone = 0
    case watch = 1
    
    var showOfflineMusicMode: Bool {
        switch self {
        case .earphone: return true
        case .watch: return false
        }
    }
    
    var showOfflineMusicControl: Bool {
        switch self {
        case .earphone: return true
        case .watch: return false
        }
    }
}

struct OfflineMusicSongListModel: Mappable {
    static let allSongListSortId = "00000000"
    
    var sortId = ""
    var playListId = ""
    var musicNum = 0
    var playListName = ""
    var musicList: [OfflineMusicSongKeyModel] = []
    
    var dataType: OfflineMusicDevice = .earphone
    
    var isCreated: Bool {
        sortId != Self.allSongListSortId
    }
    
    var isAllSongs: Bool {
        sortId == Self.allSongListSortId
    }
    
    init() {}
    
    init(sortId: String, playListId: String, musicNum: Int, playListName: String, musicList: [OfflineMusicSongKeyModel], dataType: OfflineMusicDevice) {
        self.sortId = sortId
        self.playListId = playListId
        self.musicNum = musicNum
        self.playListName = playListName
        self.musicList = musicList
        self.dataType = dataType
    }
    
    init?(map: ObjectMapper.Map) {}
    
    mutating func mapping(map: ObjectMapper.Map) {
        sortId <- map["sortId"]
        playListId <- map["playListId"]
        musicNum <- (map["musicNum"], TransformOf(fromJSON: { musicNum in
            Int(musicNum ?? "00", radix: 16) ?? 0
        }, toJSON: { "\($0 ?? 0)" }))
        playListName <- (map["playListName"], TransformOf<String, String>(fromJSON: { originalString in
            let suffixToRemove = ".lst"
            if let originalString = originalString?.components(separatedBy: "/").last,
               originalString.hasSuffix(suffixToRemove) {
                let startIndex = originalString.startIndex
                let endIndex = originalString.index(originalString.endIndex, offsetBy: -suffixToRemove.count)
                return String(originalString[startIndex..<endIndex])
            }
            return originalString
        }, toJSON: { $0 }))
        musicList <- map["musicList"]
    }
}

struct OfflineMusicSongKeyModel: Mappable, Codable, Hashable {
    var index = ""
    var key = ""
    
    init() {}
    
    init(index: String = "", key: String = "") {
        self.index = index
        self.key = key
    }
    
    init?(map: ObjectMapper.Map) {}
    
    mutating func mapping(map: ObjectMapper.Map) {
        index <- map["index"]
        key <- map["key"]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
}

struct OfflineMusicSongModel: Mappable, Hashable, Comparable {
    var index = ""
    var key = ""
    var musicPath = ""
    var musicInfo = OfflineMusicInfoModel()
    
    var dataType: OfflineMusicDevice = .earphone
    
    init(key: String, index: String = "", musicPath: String = "", musicInfo: OfflineMusicInfoModel = OfflineMusicInfoModel(), dataType: OfflineMusicDevice = .earphone) {
        self.key = key
        self.index = index
        self.musicPath = musicPath
        self.musicInfo = musicInfo
        self.dataType = dataType
    }
    
    init?(map: ObjectMapper.Map) {}
    
    mutating func mapping(map: ObjectMapper.Map) {
        musicPath <- map["musicPath"]
        musicInfo <- map["musicInfo"]
    }
    
    var isAdded = false
    var isPlaying = false
    
    static func <(lhs: Self, rhs: Self) -> Bool {
        lhs.index < rhs.index
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.key == rhs.key
    }
    
    var identity: String { key }
}

struct OfflineMusicInfoModel: Mappable, Codable {
    var duration: UInt32 = 0
    var artist = ""
    var album = ""
    var title = ""
    
    init() {}
    init(duration: UInt32, artist: String, album: String, title: String) {
        self.duration = duration
        self.artist = artist
        self.album = album
        self.title = title
    }
    
    init?(map: ObjectMapper.Map) {}
    
    mutating func mapping(map: ObjectMapper.Map) {
        duration <- map["duration"]
        artist <- map["artist"]
        album <- map["album"]
        title <- (map["title"], TransformOf<String, String>(fromJSON: {
            $0?.components(separatedBy: "/").last?.components(separatedBy: ".").first ?? ""
        }, toJSON: { $0 }))
    }
}


public extension UnsignedInteger {
    func toData(count: Int) -> Data {
        _toData(target: self, count: count)
    }
}

private func _toData<T>(target: T, count: Int) -> Data {
    var _target = target
    let data = Data(bytes: &_target, count: count)
    return Data(data.reversed())
}

extension Data {
    public init(hex: String) {
        self.init(Array<UInt8>(hex: hex))
    }
    
    public var bytes: Array<UInt8> {
        Array(self)
    }
    
    public func toHexString() -> String {
        self.bytes.toHexString()
    }
}

extension Array {
    init(reserveCapacity: Int) {
        self = Array<Element>()
        self.reserveCapacity(reserveCapacity)
    }
    
    var slice: ArraySlice<Element> {
        self[self.startIndex ..< self.endIndex]
    }
}

extension Array where Element == UInt8 {
    public init(hex: String) {
        self.init(reserveCapacity: hex.unicodeScalars.lazy.underestimatedCount)
        var buffer: UInt8?
        var skip = hex.hasPrefix("0x") ? 2 : 0
        for char in hex.unicodeScalars.lazy {
            guard skip == 0 else {
                skip -= 1
                continue
            }
            guard char.value >= 48 && char.value <= 102 else {
                removeAll()
                return
            }
            let v: UInt8
            let c: UInt8 = UInt8(char.value)
            switch c {
            case let c where c <= 57:
                v = c - 48
            case let c where c >= 65 && c <= 70:
                v = c - 55
            case let c where c >= 97:
                v = c - 87
            default:
                removeAll()
                return
            }
            if let b = buffer {
                append(b << 4 | v)
                buffer = nil
            } else {
                buffer = v
            }
        }
        if let b = buffer {
            append(b)
        }
    }
    
    public func toHexString() -> String {
        `lazy`.reduce(into: "") {
            var s = String($1, radix: 16)
            if s.count == 1 {
                s = "0" + s
            }
            $0 += s
        }
    }
}

extension Array where Element == UInt8 {
    /// split in chunks with given chunk size
    @available(*, deprecated)
    public func chunks(size chunksize: Int) -> Array<Array<Element>> {
        var words = Array<Array<Element>>()
        words.reserveCapacity(count / chunksize)
        for idx in stride(from: chunksize, through: count, by: chunksize) {
            words.append(Array(self[idx - chunksize ..< idx])) // slow for large table
        }
        let remainder = suffix(count % chunksize)
        if !remainder.isEmpty {
            words.append(Array(remainder))
        }
        return words
    }
}
