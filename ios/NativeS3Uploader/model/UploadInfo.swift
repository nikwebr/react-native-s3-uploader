//
//  UploadInfo.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 17.04.25.
//

import Foundation

class UploadInfo {
  // stored in UserDefaults
  let id: String
  private var files: [FileInfo]
  private var fileDirs: [String]
  private var state: UploadState = .initialized
  
  private let onUploadStateEvent: Events<UploadStateEvent>
  
  // existing Upload
  init(id: String, onUploadStateEvent: Events<UploadStateEvent>) throws {
    self.id = id
    self.onUploadStateEvent = onUploadStateEvent
    if let fileDirs = UserDefaults.standard.stringArray(forKey: id) {
        self.fileDirs = fileDirs
        self.files = try UploadInfo.loadFiles(fileDirs: fileDirs)
    }
    else {
      throw UploadInfoError.uploadDoesNotExist
    }
    self.state = loadState();
  }
  
  // new Upload
  init(id: String, fileDirs: [String], onUploadStateEvent: Events<UploadStateEvent>) throws {
    self.id = id
    self.onUploadStateEvent = onUploadStateEvent
    self.fileDirs = fileDirs
    self.files = try UploadInfo.loadFiles(fileDirs: fileDirs)
    if(!self.saveFileDirs(id: id, fileDirs: fileDirs)) {
      throw UploadInfoError.uploadAlreadyExists
    }
  }
  
  /**
   TODO: Könnte gleichzeitig ausgeführt werden zu einer lesenden Operation auf files (während restoreUploadProgress, z.B.)
   */
  public func addEtag(fileIndex: Int, chunkIndex: Int, eTag: String) {
    let queue = QueueManager.shared.queue(for: self.id + String(fileIndex))
    queue.sync {
      self.files[fileIndex].parts[chunkIndex].eTag = eTag
      try? self.save(fileIndex: fileIndex)
    }
  }
  
  public func shouldResumeUpload() -> Bool {
    return state == .started || state == .initialized
  }
  
  private func removeEtags() {
    self.files.enumerated().forEach { (index, file) in
      let queue = QueueManager.shared.queue(for: self.id + String(index))
      queue.async {
        self.files[index].parts = self.files[index].parts.map { part in
          var newPart = part
          newPart.eTag = nil
          return newPart
        }
        try? self.save(fileIndex: index)
      }
      
    }
  }
  
  public func getUploadCompletionInfo() throws -> [FileCompletionInfo] {
    if(state != .done) {
      throw UploadInfoError.uploadNotDone
    }
    
    var fileCompletionInfo: [FileCompletionInfo] = []
    getFiles().forEach { file in
      fileCompletionInfo.append(FileCompletionInfo(awsUploadId: file.uploadId, awsKey: file.key, parts: file.parts.enumerated().map { index, part in
        return PartCompletionInfo(ETag: part.eTag!, PartNumber: (index + 1))
      }))
    }
    
    return fileCompletionInfo
  }
  
  public func getFiles() -> [FileInfo] {
    return files
  }
  
  /*
  
  public func getNotCompletedFiles() -> [Int: FileInfo] {
    
    return files.enumerated()
      .filter { file in
      let finsihedPartCount = file.element.parts.filter { part in
        return part.eTag != nil
      }.count
      return finsihedPartCount == file.element.parts.count
    }
    .reduce(into: [Int: FileInfo]()) { dict, pair in
      dict[pair.offset] = pair.element
    }
  }
  
  public func getNotCompletedParts(fileIndex: Int) -> [Int: Part] {
    return self.files[fileIndex].parts.enumerated()
      .filter { part in
        return part.element.eTag != nil
      }
      .reduce(into: [Int: Part]()) { dict, pair in
        dict[pair.offset] = pair.element
      }
  }
   */
  
  /**
   completed = nil => all parts
   completed = true => completed parts
   completed = false => not completed parts
   */
  public func getParts(completed: Bool?, withPartSize: Bool) -> [(fileId: Int, partId: Int, part: Part, size: UInt64?)] {
    return files.enumerated().flatMap { (index, file) in
      return file.parts.enumerated().filter { part in
        if(completed == nil) {
          return true
        }
        return completed! ? isPartCompleted(part: part.element) : !isPartCompleted(part: part.element)
      }.map { part in
        var size: UInt64? = nil
        if(withPartSize) {
         size = getSizeOfPart(fileId: index, partId: part.offset)
        }
        return (fileId: index, partId: part.offset, part: part.element, size: size)
      }
    }
  }
  
  public func getSizeOfPart(fileId: Int, partId: Int) -> UInt64 {
    let url = files[fileId].parts[partId].chunkUrl
    do {
      let values = try url.resourceValues(forKeys: [.fileSizeKey])
      return UInt64(values.fileSize ?? 0)
    }
    catch {
      return 0
    }
  }
  
  public func isCompleted() -> Bool {
    if(state == .done) {
      return true
    }
    let completedCount = getParts(completed: true, withPartSize: false).count
    let totalCount = getParts(completed: nil, withPartSize: false).count

    let completed = completedCount == totalCount
    if(completed) {
      state = .done
      onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
      saveState()
    }
    return completed
  }
  
  public func error() {
    state = .error
    onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
    saveState()
  }
  
  public func cancel() throws {
    if(state == .done) {
      throw UploadInfoError.cancelCalledOnUploadThatIsDone
    }
   
    self.removeEtags()
    state = .canceled
    onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
    saveState()
  }
  
  public func pause() throws {
    if(state != .started) {
      throw UploadInfoError.pauseCalledOnUploadThatIsNotStarted
    }
    
    state = .paused
    onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
    saveState()
  }
  
  public func resume() throws {
    if(state != .paused) {
      throw UploadInfoError.resumeCalledOnUploadThatIsNotPaused
    }
    state = .started
    onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
    saveState()
  }
  
  public func restart() throws {
    if(state != .canceled) {
      throw UploadInfoError.restartCalledOnUploadThatIsNotCanceled
    }
  }
  
  public func upload() {
    state = .started
    onUploadStateEvent.trigger(event: UploadStateEvent(uploadId: self.id, state: state.rawValue))
    saveState()
  }
  
  public func delete() throws {
    try fileDirs.indices.forEach { index in
      let url = try UploadInfo.getFileURL(fileDirs: fileDirs, fileIndex: index, chunkIndex: nil)
      try FileManager.default.removeItem(at: url)
    }
    
    UserDefaults.standard.removeObject(forKey: self.id)
  }
  
  public func getState() -> UploadState {
    return state;
  }
  
  private func isPartCompleted(part: Part) -> Bool {
    return part.eTag != ""
  }
  
  private func save(fileIndex: Int) throws {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(files[fileIndex])
        let s3URL = try getS3URL(fileIndex: fileIndex)
        try jsonData.write(to: s3URL, options: .atomic)
    } catch {
      throw UploadInfoError.s3DetailsWritingError
    }
    
  }
  
  private static func loadFiles(fileDirs: [String]) throws -> [FileInfo] {
    let fileManager = FileManager.default
    let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
    
    var files: [FileInfo] = []
    
    try fileDirs.indices.forEach { index in
      let url = try UploadInfo.getFileURL(fileDirs: fileDirs, fileIndex: index, chunkIndex: nil)
      do {
        let jsonData = try Data(contentsOf: url.appendingPathComponent("s3.json"))
        let decoder = JSONDecoder()
        let file = try decoder.decode(FileInfo.self, from: jsonData)
        files.append(file)
      }
      catch {
        throw UploadInfoError.s3DetailsParsingError
      }
      
      if let chunkUrls = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) {
          for chunkUrl in chunkUrls {
              let chunkName = chunkUrl.deletingPathExtension().lastPathComponent
              if let partNumber = Int(chunkName) {
                files[index].parts[partNumber].chunkUrl = chunkUrl
              }
          }
      }
      else {
        throw UploadInfoError.chunkImportError
      }
      
     
      
    }
    
    return files
  }
  
  private static func getFileURL(fileDirs: [String], fileIndex: Int, chunkIndex: Int?) throws -> URL {
    var url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("uploads").appendingPathComponent(fileDirs[fileIndex])
    
    if(chunkIndex != nil) {
      url = url.appendingPathComponent(String(chunkIndex!))
    }
    
    return url
  }
  
  private func getFileURL(fileIndex: Int, chunkIndex: Int?) throws -> URL {
    return try UploadInfo.getFileURL(fileDirs: self.fileDirs, fileIndex: fileIndex, chunkIndex: chunkIndex)
  }
  
  private func getS3URL(fileIndex: Int) throws -> URL {
    return try getFileURL(fileIndex: fileIndex, chunkIndex: nil).appendingPathComponent("s3.json")
  }
  
  private func saveFileDirs(id: String, fileDirs: [String]) -> Bool {
    UserDefaults.standard.set(fileDirs, forKey: id)
    return true
  }
  
  private func saveState() {
    UserDefaults.standard.set(state.rawValue, forKey: "upload-state-" + id)
  }
  
  private func loadState() -> UploadState {
    let rawValue = UserDefaults.standard.string(forKey: "upload-state-" + id)
    if(rawValue != nil) {
      return UploadState(rawValue: rawValue!)!
    }
    return .started
  }
}
