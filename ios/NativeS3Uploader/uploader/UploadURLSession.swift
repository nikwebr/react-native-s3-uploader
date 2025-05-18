//
//  SessionManager.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 23.04.25.
//

import Foundation


struct QueuedETag {
  let ETag: String
  let FileId: Int
  let PartId: Int
  let UploadId: String
}

public class UploadURLSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
  private let backgroundIdentifier = "\( String(describing: Bundle.main.bundleIdentifier) ).background"
  private var uploadSession: URLSession?
  private var uploads: Uploads
  private let delegateQueue = OperationQueue()
  
  private var isInitialized = false
  private var initTask: Task<Void, Error>?
  private var continuation: CheckedContinuation<Void, Never>?
  private var hasBeenTriggered = false
  private var initTime: Date = Date()
  
  public init(uploads: Uploads) {
    self.uploads = uploads
    super.init()
    self.initTask = Task {
      await waitForTriggerOrTimeout()
    }
  }
  
  public func uploadsLoaded() {
    self.initTime = Date()
    self.createSession()
  }
  
  public func addUpload(upload: Upload) {
    uploads.addUpload(upload: upload)
  }
  
  
  public func uploadPart(part: Part, partIndex: Int, fileIndex: Int, uploadId: String) async {
    var task = await getTask(uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex)
    if(task != nil && (task!.state == .completed || task!.state == .running)) {
      task!.resume()
      return
    }
    else if(task != nil) {
      task?.cancel()
    }
    var request = URLRequest(url: part.uploadUrl)
    request.httpMethod = "PUT"
    if(part.chunkUrl.absoluteString != "https://example.com") {
      task = uploadSession!.uploadTask(with: request, fromFile: part.chunkUrl)
      task!.taskDescription = "\(uploadId)-\(fileIndex)-\(partIndex)"
      task!.resume()
    }
   
  }
  
  /**
   Cancels all parts that match the given inputs. If nil is used, this input does not count for selecting tasks
   */
  public func cancelParts(uploadId: String?, fileIndex: Int?, partIndex: Int?) async {
    await getTasks(uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex).forEach { task in
      task.cancel()
    }
  }
  
  public func pauseParts(uploadId: String?, fileIndex: Int?, partIndex: Int?) async {
    await getTasks(uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex).forEach { task in
      task.suspend()
    }
  }
  
  public func resumeParts(uploadId: String?, fileIndex: Int?, partIndex: Int?) async {
    await getTasks(uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex).forEach { task in
      task.resume()
    }
  }
  
  /**
   returns only parts that have already started uploaded (sentBytes > 0)
   */
  func getBytesSent(uploadId: String) async -> [(fileId: Int, partId: Int, sent: UInt64)] {
    let tasks = await getTasks(uploadId: uploadId, fileIndex: nil, partIndex: nil)
    return tasks.filter { task in
      return (task.state == .running || task.state == .suspended || task.state == .completed) && task.countOfBytesSent > 0
    }.map { task in
      let parsed = parseTaskDescription(description: task.taskDescription)
      if(parsed == nil) {
        return (fileId: 0, partId: 0, sent: 0)
      }
      return (fileId: parsed!.fileId, partId: parsed!.partId, sent: UInt64(task.countOfBytesSent))
    }
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                  totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    let upload = getUploadByTask(task: task)
    if(upload == nil) {
    }
    upload?.bytesSent(sentBytes: bytesSent)
  }

  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    if let httpResponse = dataTask.response as? HTTPURLResponse {
      if(httpResponse.statusCode >= 400) {
        Task {
          try await getUploadByTask(task: dataTask)?.error()
        }
        return
      }
    }
    
    if let httpResponse = dataTask.response as? HTTPURLResponse,
       let eTag = httpResponse.allHeaderFields["Etag"] as? String {
      let info = parseTaskDescription(description: dataTask.taskDescription)
      getUploadByTask(task: dataTask)?.partUploaded(etag: eTag, fileId: info!.fileId, partId: info!.partId)
    }
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    triggerInitializationDone()
    for upload in uploads.getUploads() {
      upload.value.complete()
    }
  }
  
  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    
    if let nsError = error as NSError? {
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorCancelled: // == -999
                    return
                default:
                  Task {
                    try await getUploadByTask(task: task)?.error()
                  }
                }
            } else {
              Task {
                try await getUploadByTask(task: task)?.error()
              }
            }
        }
  }
  
  private func getTask(uploadId: String, fileIndex: Int, partIndex: Int) async -> URLSessionTask? {
    let task = await getTasks(uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex)
    if(task.count == 0) {
      return nil
    }
    return task[0]
  }
  
  private func getTasks(uploadId: String?, fileIndex: Int?, partIndex: Int?) async -> [URLSessionTask] {
    let tasks = await uploadSession!.allTasks
    return tasks.filter { task in
      return matchesDescription(description: task.taskDescription, uploadId: uploadId, fileIndex: fileIndex, partIndex: partIndex)
    }
    }
  
  private func matchesDescription(description: String?, uploadId: String?, fileIndex: Int?, partIndex: Int?) -> Bool {
    let parsed = parseTaskDescription(description: description)
    if(parsed == nil) {
      return false
    }
    
    let taskFileIndex = parsed?.fileId
    let taskPartIndex = parsed?.partId
    let taskUploadId = parsed?.uploadId
    
    var matches = true
    if(uploadId != nil && taskUploadId != uploadId) {
      matches = false
    }
    if(fileIndex != nil && taskFileIndex != fileIndex) {
      matches = false
    }
    if(partIndex != nil && taskPartIndex != partIndex) {
      matches = false
    }
    return matches
  }
  
  private func parseTaskDescription(description: String?) -> (uploadId: String, fileId: Int, partId: Int)? {
    if(description == nil) {
      return nil
    }
      
    let components = description!.split(separator: "-")
    let taskFileIndex = Int(components[1])
    let taskPartIndex = Int(components[2])
    let taskUploadId = String(components[0])
    if(taskPartIndex == nil || taskFileIndex == nil) {
      return nil
    }
    
    return (uploadId: taskUploadId, fileId: taskFileIndex!, partId: taskPartIndex!)
  }
  
  private func getUploadByTask(task: URLSessionTask) -> Upload? {
    let info = parseTaskDescription(description: task.taskDescription)
    if(info == nil) {
      return nil
    }
    return self.uploads.getUpload(id: info!.uploadId)
  }
  
  private func createSession() {
    delegateQueue.maxConcurrentOperationCount = 1
    delegateQueue.qualityOfService = .userInitiated
    let config = URLSessionConfiguration.background(withIdentifier: self.backgroundIdentifier)
    config.sessionSendsLaunchEvents = true
    //config.timeoutIntervalForResource = 30
    
    self.uploadSession = URLSession(configuration: config, delegate: self, delegateQueue: self.delegateQueue)
  }
  
  private func triggerInitializationDone() {
    hasBeenTriggered = true
    continuation?.resume()
    continuation = nil
  }

     // Die Methode wartet entweder auf `trigger()` oder auf 2 Sekunden Timeout
   private func waitForTriggerOrTimeout() async {
         await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
             self.continuation = continuation

             // Timeout nach 2 Sekunden seit Initialisierung
             let elapsed = Date().timeIntervalSince(self.initTime)
             let remaining = max(0, 2.0 - elapsed)

             DispatchQueue.global().asyncAfter(deadline: .now() + remaining) {
                 if !self.hasBeenTriggered {
                     continuation.resume()
                     self.continuation = nil
                 }
             }
         }
     }
  
  public func awaitInitialization() async throws {
    try await initTask!.value
  }
}
