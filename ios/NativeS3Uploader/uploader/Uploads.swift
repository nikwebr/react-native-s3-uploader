//
//  Uploads.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 29.04.25.
//

import Foundation

public class Uploads {
  private var threadUnsafeDict = [String: Upload]()
  private let dispatchQueue = DispatchQueue(label: UUID().uuidString, attributes: .concurrent)
  private let storageName: String?

  public init() {
    self.storageName = nil
  }
  
  /**
   loads Uploads from storage
   */
  public init(storageName: String) {
    self.storageName = storageName
  }
  
  public func load(session: UploadURLSession, onProgressEvent: Events<UploadProgressEvent>, onUploadStateEvent: Events<UploadStateEvent>) throws {
    let uploadIds = getUploadIds()
    if(uploadIds != nil) {
      var uploads: [String: Upload] = [:]
      for id in uploadIds! {
        let upload = try Upload(id: id, session: session, onProgressEvent: onProgressEvent, onUploadStateEvent: onUploadStateEvent)
          uploads[id] = upload
      }
      
      dispatchQueue.sync(flags: .barrier) {
        for (id, upload) in uploads {
          threadUnsafeDict[id] = upload
        }
      }
    }
  }

  public func getUploads() -> [String: Upload] {
    var result: [String: Upload] = [:]
      dispatchQueue.sync {
          result = threadUnsafeDict
      }
      return result
  }
  
  public func getUpload(id: String) -> Upload? {
    var result: Upload?
    dispatchQueue.sync {
        result = threadUnsafeDict[id]
    }
    return result
  }

      public func addUpload(upload: Upload) -> Bool {
          var error = false
          dispatchQueue.sync(flags: .barrier) {
            if(self.threadUnsafeDict[upload.getId()] != nil) {
              error = true
            }
            else {
              self.threadUnsafeDict[upload.getId()] = upload
              self.save()
            }
          }
        return error
      }
  
  public func removeUpload(id: String) {
    dispatchQueue.async(flags: .barrier) {
      let upload = self.threadUnsafeDict[id]
      if(upload != nil) {
        Task {
          try await upload!.delete()
        }
      }
      self.threadUnsafeDict.removeValue(forKey: id)
      self.save()
    }
}
  
  public func refreshProgress() {
    dispatchQueue.sync {
      threadUnsafeDict.forEach{ index, upload in
        Task {
          try await upload.calculateProgress()
        }
      }
    }
  }
  
  /**
   May only be called from a save context (inside a lock)
   */
  private func save() {
    if(storageName != nil) {
      UserDefaults.standard.set(Array(self.threadUnsafeDict.keys), forKey: storageName!)
    }
  }
  
  /**
   May only be called from a save context
   */
  private func getUploadIds() -> [String]? {
    if(storageName != nil) {
      return UserDefaults.standard.object(forKey: self.storageName!) as? [String]
    }
    return []
  }
}
