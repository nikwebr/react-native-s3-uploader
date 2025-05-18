//
//  Event.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 05.05.25.
//

import Foundation

public class Events<EventItem> {
  private var callback: ((EventItem) -> Void)?
  private var isListening = false;
  private var buffer: [EventItem] = [];
  
  public func trigger(event: EventItem) {
    if(isListening && callback != nil) {
      callback!(event)
    }
    else {
      buffer.append(event)
    }
  }
  
  public func registerCallback(callback: @escaping ((EventItem) -> Void)) {
    self.callback = callback
    sendBufferedEvents()
  }
  
  public func startSending() {
    isListening = true
    sendBufferedEvents()
  }
  
  private func sendBufferedEvents() {
    if(isListening && callback != nil) {
      buffer.forEach{ bufferedEvent in
        callback!(bufferedEvent)
      }
      buffer.removeAll()
    }
  }
}

public struct UploadProgressEvent {
  let uploadId: String
  let progress: Double
}

public struct UploadStateEvent {
  let uploadId: String
  let state: String
}
