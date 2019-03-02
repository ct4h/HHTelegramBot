//
//  PaginationManager.swift
//  App
//
//  Created by basalaev on 16/12/2018.
//

import Foundation
import Async
import LoggerAPI

class PaginationManager<T: Decodable & PagintaionResponse> {

    typealias RequestFactory = (Int, Int) -> ApiTarget

    private let worker: Worker
    private let apiClient: ApiClient
    private let limit: Int

    init(host: String, port: Int, access: String, limit: Int = 100, worker: Worker) {
        self.worker = worker
        self.apiClient = ApiClient(host: host, port: port, access: access, worker: worker)
        self.limit = limit
    }

    func all(requestFactory: @escaping RequestFactory) -> Future<[T.ItemsType]> {
        let promise = worker.eventLoop.newPromise([T.ItemsType].self)

        worker.eventLoop.execute { [weak self] in
            self?._all(requestFactory: requestFactory, offset: 0, buffer: [], promise: promise)
        }

        return promise.futureResult
    }

    private func _all(requestFactory: @escaping RequestFactory, offset: Int, buffer: [T.ItemsType], promise: Promise<[T.ItemsType]>) {

        let requestPromise: Future<T> = apiClient.respond(target: requestFactory(offset, limit))

        requestPromise.whenSuccess { [weak self] (response: T) in
            let result = buffer + response.items

            if response.isFinished {
                promise.succeed(result: result)
            } else {
                self?._all(requestFactory: requestFactory, offset: response.nextOffset, buffer: result, promise: promise)
            }
        }

        requestPromise.whenFailure { (error) in
            promise.fail(error: error)
        }
    }
}
