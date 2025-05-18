//
//  StateManager.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 23.04.25.
//

import Foundation

public class Upload: NSObject {
  private let uploadInfo: UploadInfo
  private var totalBytesSent: UInt64 = 0
  private var totalBytesExpected: UInt64 = 0
  private var session: UploadURLSession
  
  private var timer: DispatchSourceTimer?
  
  private let dispatchQueue = DispatchQueue(label: UUID().uuidString, attributes: .concurrent)
  
  private let onProgressEvent: Events<UploadProgressEvent>
  
  public init(id: String, session: UploadURLSession, onProgressEvent: Events<UploadProgressEvent>, onUploadStateEvent: Events<UploadStateEvent>) throws {
    self.uploadInfo = try UploadInfo(id: id, onUploadStateEvent: onUploadStateEvent)
    self.session = session
    self.onProgressEvent = onProgressEvent
    super.init()
    self.session.addUpload(upload: self)
    self.initProgress()
    self.initTimer()
    Task {
      try await self.calculateProgress()
      try await self.startResumeUpload()
    }
    
  }
  
  public init(id: String, fileDirs: [String], session: UploadURLSession, onProgressEvent: Events<UploadProgressEvent>, onUploadStateEvent: Events<UploadStateEvent>) throws {
    self.uploadInfo = try UploadInfo(id: id, fileDirs: fileDirs, onUploadStateEvent: onUploadStateEvent)
    self.session = session
    self.onProgressEvent = onProgressEvent
    super.init()
    self.session.addUpload(upload: self)
    self.initProgress()
    self.initTimer()
    Task {
      try await self.calculateProgress()
      try await self.startResumeUpload()
    }
  }
  
  public func abort() async throws {
    try self.uploadInfo.cancel()
    await session.cancelParts(uploadId: uploadInfo.id, fileIndex: nil, partIndex: nil)
    self.totalBytesSent = 0
    timer?.cancel()
  }
  
  public func error() async throws {
    try await self.abort()
    uploadInfo.error()
  }
  
  public func getUploadCompletionInfo() throws -> [FileCompletionInfo] {
    return try uploadInfo.getUploadCompletionInfo()
  }
  
  // can only be paused if state is .started
  public func pause() async throws {
    try uploadInfo.pause()
    await session.pauseParts(uploadId: uploadInfo.id, fileIndex: nil, partIndex: nil)
  }
  
  // can only be resumed if state is .paused
  public func resume() async throws {
    try uploadInfo.resume()
    await session.resumeParts(uploadId: uploadInfo.id, fileIndex: nil, partIndex: nil)
  }
  
  public func restart() async throws {
    try uploadInfo.restart()
    try await startResumeUpload()
  }
  
  public func getProgress() -> Double {
    dispatchQueue.sync {
      return Double(self.totalBytesSent) / Double(self.totalBytesExpected);
    }
  }
  
  public func getId() -> String {
    return uploadInfo.id
  }
  
  public func bytesSent(sentBytes: Int64) {
    dispatchQueue.sync(flags: .barrier) {
      self.totalBytesSent += UInt64(sentBytes)
      let progress = Double(self.totalBytesSent) / Double(self.totalBytesExpected)
      onProgressEvent.trigger(event: UploadProgressEvent(uploadId: self.getId(), progress: progress))
    }
  }
  
  public func partUploaded(etag: String, fileId: Int, partId: Int) {
    self.uploadInfo.addEtag(fileIndex: fileId, chunkIndex: partId, eTag: etag)
    let completedParts = uploadInfo.getParts(completed: true, withPartSize: true)
    if(uploadInfo.isCompleted()) {
      complete()
    }
  }
  
  public func complete() {
    if(!uploadInfo.isCompleted()) {
      return
    }
    self.totalBytesSent = self.totalBytesExpected
    timer?.cancel()
  }
  
  public func delete() async throws {
    await session.cancelParts(uploadId: uploadInfo.id, fileIndex: nil, partIndex: nil)
    timer?.cancel()
    try self.uploadInfo.delete()
  }
  
  public func getState() -> UploadState {
    return uploadInfo.getState()
  }
  
  public func startResumeUpload() async throws {
    if(!uploadInfo.shouldResumeUpload()) {
      return
    }
    
    let parts = uploadInfo.getParts(completed: false, withPartSize: false)
    for (fileIndex, partIndex, part, size) in parts {
      await session.uploadPart(part: part, partIndex: partIndex, fileIndex: fileIndex, uploadId: uploadInfo.id)
    }
    
    if(parts.count > 0) {
      self.uploadInfo.upload()
    }
  }
  
  private func initProgress() {
    dispatchQueue.sync(flags: .barrier) {
      self.totalBytesExpected = uploadInfo.getParts(completed: nil, withPartSize: true).reduce(0) { sum, part in
        return sum + part.size!
      }
      
      let completedParts = uploadInfo.getParts(completed: true, withPartSize: true)
      self.totalBytesSent = completedParts.reduce(0) { sum, part in
        return sum + part.size!
      }
    }
  }
  
  public func calculateProgress() async throws {
    try await session.awaitInitialization()
    var tasksInProgress = await session.getBytesSent(uploadId: uploadInfo.id)
    
    dispatchQueue.sync(flags: .barrier) {
      let completedParts = uploadInfo.getParts(completed: true, withPartSize: true)
      var sentBytes: UInt64 = completedParts.reduce(0) { sum, part in
        return sum + part.size!
      }
      
      tasksInProgress.removeAll { task in
        return completedParts.contains { (fileId, partId, part, size) in
          return fileId == task.fileId && partId == task.partId
        }
      }
      
      sentBytes = tasksInProgress.reduce(sentBytes) { sum, part in
        return sum + part.sent
      }
      
      self.totalBytesSent = sentBytes
    }
  }
  
  private func initTimer() {
    timer = DispatchSource.makeTimerSource()
            timer?.schedule(deadline: .now() + 5, repeating: 5.0)
            timer?.setEventHandler { [weak self] in
              Task {
                try await self?.calculateProgress()
              }
            }
            timer?.resume()
  }
  
  deinit {
          timer?.cancel()
      }
}
