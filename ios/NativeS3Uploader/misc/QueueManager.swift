//
//  QueueManager.swift
//  RNS3Uploader
//
//  Created by Niklas Weber on 26.04.25.
//

import Foundation

final class QueueManager {
    static let shared = QueueManager()
    private var queues: [String: DispatchQueue] = [:]
    private let accessQueue = DispatchQueue(label: "queueManager")

    func queue(for identifier: String) -> DispatchQueue {
        accessQueue.sync {
            if let existingQueue = queues[identifier] {
                return existingQueue
            } else {
              let newQueue = DispatchQueue(label: UUID().uuidString)
                queues[identifier] = newQueue
                return newQueue
            }
        }
    }
}

