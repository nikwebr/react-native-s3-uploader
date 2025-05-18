//
//  FileInfo.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 26.04.25.
//

import Foundation

public struct FileInfo: Codable {
    let key: String             // stored in s3.json file in each file dir
    let uploadId: String        // stored in s3.json file in each file dir
    var parts: [Part]           // stored in s3.json file in each file dir
}

public struct Part: Codable {
    var eTag: String?
    let uploadUrl: URL
  var chunkUrl: URL = URL(string: "https://example.com")!
  
  enum CodingKeys: String, CodingKey {
      case eTag
      case uploadUrl
  }
}

@objc public class FileCompletionInfo: NSObject {
  let awsUploadId: String
  let awsKey: String
  let parts: [PartCompletionInfo]
  
  init(awsUploadId: String, awsKey: String, parts: [PartCompletionInfo]) {
    self.awsUploadId = awsUploadId
    self.awsKey = awsKey
    self.parts = parts
  }
  
  func toDictionary() -> [String: Any] {
      return [
        "awsUploadId": awsUploadId,
        "awsKey": awsKey,
        "parts": parts.map { $0.toDictionary() }
      ]
    }
}

@objc class PartCompletionInfo: NSObject {
  let ETag: String
  let PartNumber: Int
  
  init(ETag: String, PartNumber: Int) {
    self.ETag = ETag
    self.PartNumber = PartNumber
  }
  
  func toDictionary() -> [String: Any] {
     return [
       "ETag": ETag,
       "PartNumber": PartNumber
     ]
   }
}
