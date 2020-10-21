//
//  HurmaRepository.swift
//  App
//
//  Created by basalaev on 08.10.2020.
//

import Foundation
import Async
import LoggerAPI

final class HurmaRepository {
    private let apiClient: ApiClient
    private let worker: Worker
    private var dateCache: Date?
    private var cachedPromise: Promise<[HurmaUser]>?

    init(worker: Worker) {
        let arguments = RuntimeArguments.Hurma()
        self.apiClient = ApiClient(
            host: arguments.host,
            port: arguments.port,
            access: ("token", arguments.token),
            worker: worker
        )
        self.worker = worker
    }

    func users() -> Future<[HurmaUser]> {
        if let dateCache = dateCache, dateCache.addingTimeInterval(3_600) <= Date() {
            self.cachedPromise = nil
        }

        if let cachedPromise = cachedPromise {
            Log.info("HurmaRepository use cache")
            return cachedPromise.futureResult
        }

        let promise = worker.eventLoop.newPromise([HurmaUser].self)
        self.cachedPromise = promise

        usersReponse()
            .map { $0.result.data }
            .whenSuccess { [weak self] (result) in
                self?.dateCache = Date()
                promise.succeed(result: result)
            }

        return promise.futureResult
    }

    private func usersReponse() -> Future<HurmaUsersResponse> {
        return apiClient.respond(target: HurmaRequests.users)
    }
}
