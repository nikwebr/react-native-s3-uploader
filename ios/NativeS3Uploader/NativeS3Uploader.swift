//
//  S3Uploader.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 17.04.25.
//



import Foundation
import UserNotifications
import React

@objc public final class NativeS3Uploader: NSObject {
  private let uploads: Uploads
  private let uploadSession: UploadURLSession
  
  private let uploadProgressEvents = Events<UploadProgressEvent>();
  private let uploadStateEvents = Events<UploadStateEvent>();
    
  public static let shared = NativeS3Uploader()
  
  private override init() {
    self.uploads = Uploads(storageName: "uploads")
    self.uploadSession = UploadURLSession(uploads: self.uploads)
    try! self.uploads.load(session: uploadSession, onProgressEvent: uploadProgressEvents, onUploadStateEvent: uploadStateEvents)
    self.uploadSession.uploadsLoaded()
    super.init()
    NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshProgress),
                                           name: UIApplication.didBecomeActiveNotification,
                                           object: nil)
  }
  
  @objc public func registerProgressCallback(callback: @escaping (NSString, NSNumber) -> Void) {
    let wrappedCallback: (UploadProgressEvent) -> Void = { event in
      callback(NSString(string: event.uploadId), NSNumber(value: event.progress))
            }
    self.uploadProgressEvents.registerCallback(callback: wrappedCallback)
  }
  
  @objc public func registerStateCallback(callback: @escaping (NSString, NSString) -> Void) {
    let wrappedCallback: (UploadStateEvent) -> Void = { event in
      callback(NSString(string: event.uploadId), NSString(string: event.state))
            }
    self.uploadStateEvents.registerCallback(callback: wrappedCallback)
  }
  
  @objc public func getUploads() -> [String] {
    return Array(self.uploads.getUploads().keys)
  }
  
  @objc public func getUploadCompletionInfo(id: String) throws -> [[String: Any]] {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      throw NativeS3UploaderError.uploadNotFound
    }
    let infos = try upload!.getUploadCompletionInfo()
    return infos.map { info in
      return info.toDictionary()
    }
  }
  
  @objc public func upload(id: String, fileDirs: [String]) throws {
    try Upload(id: id, fileDirs: fileDirs, session: uploadSession, onProgressEvent: self.uploadProgressEvents, onUploadStateEvent: self.uploadStateEvents)
  }
  
  @objc public func cancel(id: String, _ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      reject("CANCEL", "upload not found", NativeS3UploaderError.uploadNotFound)
    }
    Task {
      do {
        try await upload!.abort()
        resolve("")
      }
      catch {
        reject("CANCEL", error.localizedDescription, error)
      }
    }
  }
  
  @objc public func pause(id: String, _ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      reject("PAUSE", "upload not found", NativeS3UploaderError.uploadNotFound)
    }
    Task {
      do {
        try await upload!.pause()
        resolve("")
      }
      catch {
        reject("PAUSE", error.localizedDescription, error)
      }
    }
  }
  
  @objc public func resume(id: String, _ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      reject("RESUME", "upload not found", NativeS3UploaderError.uploadNotFound)
    }
    Task {
      do {
        try await upload!.resume()
        resolve("")
      }
      catch {
        reject("RESUME", error.localizedDescription, error)
      }
      
    }
  }
  
  @objc public func restart(id: String, _ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      reject("RESTART", "upload not found", NativeS3UploaderError.uploadNotFound)
    }
    Task {
      do {
        try await upload!.restart()
        resolve("")
      }
      catch {
        reject("RESTART", error.localizedDescription, error)
      }
    }
  }
  
  @objc public func clear(id: String) {
    uploads.removeUpload(id: id)
  }
  
  
  @objc public func listenersReady() {
    uploadProgressEvents.startSending()
    uploadStateEvents.startSending()
  }
  
  
  // TODO: Hier kommt Parallelität rein. Alles was in Task steht kann parallel ausgeführt werden!
  
  @objc public func getProgress(id: String) throws -> NSNumber {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      throw NativeS3UploaderError.uploadNotFound
    }
    return NSNumber(value: uploads.getUpload(id: id)!.getProgress())
  }
  
  @objc public func getState(id: String) throws -> NSString {
    let upload = uploads.getUpload(id: id)
    if(upload == nil) {
      throw NativeS3UploaderError.uploadNotFound
    }
    return NSString(string: uploads.getUpload(id: id)!.getState().rawValue)
  }
  
  @objc public static func get() -> NativeS3Uploader {
    return NativeS3Uploader.shared
  }
  
  @objc public func refreshProgress() {
    uploads.refreshProgress()
  }
}

