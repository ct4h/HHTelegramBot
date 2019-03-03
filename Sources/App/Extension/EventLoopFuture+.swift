//
//  EventLoopFuture+.swift
//  App
//
//  Created by basalaev on 03/03/2019.
//

import Foundation
import NIO

private struct EventLoopFutureError: Error {
}

extension EventLoopFuture {

    func thenFuture<U>(file: StaticString = #file, line: UInt = #line, _ callback: @escaping (T) throws -> EventLoopFuture<U>?) -> EventLoopFuture<U> {

        return then(file: file, line: line) { (value) -> EventLoopFuture<U> in
            do {
                if let future = try callback(value) {
                    return future
                } else {
                    return self.error(error: EventLoopFutureError())
                }
            } catch {
                return self.error(error: error)
            }
        }
    }

    func throwingSuccess(_ callback: @escaping (T) throws -> Void) {
        whenSuccess { (value) in
            do {
                try callback(value)
            } catch {
            }
        }
    }

    private func error<U>(error: Error) -> EventLoopFuture<U> {
        let promise = eventLoop.newPromise(U.self)
        promise.fail(error: error)
        return promise.futureResult
    }
}
