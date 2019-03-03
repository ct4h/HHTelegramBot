//
//  InlineCommandsBuffer.swift
//  App
//
//  Created by basalaev on 03/03/2019.
//

import Foundation
import LoggerAPI

private struct _InlineCommandsGroup {
    let id: Int
    let context: String
    let originalQueries: [String]
    let proxedQueries: [String]
    var chatID: Int64?
    var messageID: Int?

    init(id: Int, context: String, queries: [String]) {
        Log.info("Create inline group id \(id) context \(context)")
        self.id = id
        self.context = context

        var originalQueries: [String] = []
        var proxedQueries: [String] = []

        for query in queries {
            let proxedQuery = "\(context)?\(id)_\(proxedQueries.count)"
            originalQueries.append(query)
            proxedQueries.append(proxedQuery)
        }

        self.originalQueries = originalQueries
        self.proxedQueries = proxedQueries
    }

    var publicInlineCommandsGroup: InlineCommandsGroup {
        return InlineCommandsGroup(id: id, context: context, queries: proxedQueries)
    }

    func query(callbackData: String) -> String? {
        if let index = proxedQueries.firstIndex(where: { $0 == callbackData }) {
            return originalQueries[safe: index]
        } else {
            return nil
        }
    }
}

struct InlineCommandsGroup {
    let id: Int
    let context: String
    let queries: [String]
}

class InlineCommandsBuffer {

    static let shared = InlineCommandsBuffer()

    private let queue = DispatchQueue(label: "INLINE-COMMANDS-BUFFER-QUEUE", attributes: .concurrent)
    private var groups: [_InlineCommandsGroup] = []

    private init() {}

    func registrate(context: String, queries: [String]) -> InlineCommandsGroup {
        return queue.sync(flags: .barrier) { () -> InlineCommandsGroup in
            let group = _InlineCommandsGroup(id: groups.count, context: context, queries: queries)
            groups.append(group)
            return group.publicInlineCommandsGroup
        }
    }

    func query(callbackData: String) -> String? {
        return queue.sync(flags: .barrier) { () -> String? in
            Log.info("Groups count \(groups.count)")
            let result = groups.compactMap { $0.query(callbackData:callbackData) }.first
            Log.info("Search query \(String(describing: result)) for \(callbackData)")
            return result
        }
    }

    func update(group: InlineCommandsGroup, chatID: Int64, messageID: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }

            Log.info("Update \(group.id) \(group.context) chatID \(chatID) messageID \(messageID)")

            if let index = self.groups.firstIndex(where: { $0.id == group.id }) {
                var _group = self.groups[index]
                _group.chatID = chatID
                _group.messageID = messageID
                self.groups[index] = _group
            }
        }
    }

    func deleteGroup(chatID: Int64, messageID: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }

            Log.info("Delete chatID \(chatID) messageID \(messageID)")

            self.groups.removeAll(where: { $0.chatID == chatID && $0.messageID == messageID })
        }
    }
}
