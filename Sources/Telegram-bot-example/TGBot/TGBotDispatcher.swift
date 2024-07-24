//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 24.07.2024.
//

import Foundation
import Logging
import SwiftTelegramSdk

final class TGBotDispatcher: TGDispatcherPrtcl {
    public var handlersGroup: [[TGHandlerPrtcl]] = []
    private var log: Logger
    private var handlersId: Int = 0
    private var nextHandlerId: Int {
        handlersId += 1
        return handlersId
    }
    private var index: Int = 0

    private typealias Level = Int
    private typealias IndexId = Int
    private typealias Position = Int
    private var handlersIndex: [Level: [IndexId: Position]] = .init()

    required public init(log: Logger) async throws {
        self.log = log
        try await handle()
    }
    
    func handle() async throws {}

    public func add(_ handler: TGHandlerPrtcl, priority: Int) {
        /// add uniq index id
        var handler: TGHandlerPrtcl = handler
        handler.id = nextHandlerId
        
        /// add handler
        var handlerPosition: Int = 0
        let correctLevel: Int = priority >= 0 ? priority : 0
        if handlersGroup.count > correctLevel {
            self.handlersGroup[correctLevel].append(handler)
            handlerPosition = handlersGroup[correctLevel].count - 1
        } else {
            handlersGroup.append([handler])
            handlerPosition = handlersGroup[handlersGroup.count - 1].count - 1
        }
        
        /// add handler to index
        if handlersIndex[priority] == nil { handlersIndex[priority] = .init() }
        handlersIndex[priority]?[handler.id] = handlerPosition
    }

    public func add(_ handler: TGHandlerPrtcl) async {
        add(handler, priority: 0)
    }

    public func remove(_ handler: TGHandlerPrtcl, from priority: Int?) {
        let priority: Level = priority ?? 0
        let indexId: IndexId = handler.id
        guard
            let index: [IndexId: Position] = handlersIndex[priority],
            let position: Position = index[indexId]
        else {
            return
        }
        let positionIndex = position - 1
        if
            handlersGroup[priority].count > positionIndex,
            handlersGroup[priority][positionIndex].id == handler.id
        {
            handlersGroup[priority].remove(at: positionIndex)
            handlersIndex[priority]?.removeValue(forKey: indexId)
        }
    }
    
    public func process(_ updates: [TGUpdate]) {
        Task.detached(priority: .high) { [log] in
            for update in updates {
                do {
                    try await self.processByHandler(update)
                } catch {
                    log.error("\(makeError(BotError(String(describing: error))).localizedDescription)")
                }
            }
        }
    }
    
    private func processByHandler(_ update: TGUpdate) async throws {
        log.trace("\(dump(update))")
        if handlersGroup.isEmpty { return }
        
        for i in 1...handlersGroup.count {
            for handler in handlersGroup[handlersGroup.count - i] {
                if handler.check(update: update) {
                    try await handler.handle(update: update)
                }
            }
        }
    }
}
