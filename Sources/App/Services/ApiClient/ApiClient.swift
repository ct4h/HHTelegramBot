//
//  ApiClient.swift
//  App
//
//  Created by basalaev on 24/11/2018.
//

import Foundation
import HTTP
import Async
import LoggerAPI

class ApiClient {
    private let host: String
    private let port: Int
    private let access: (key: String, value: String)
    private let worker: Worker
    private var client: HTTPClient?

    init(host: String, port: Int, access: (key: String, value: String), worker: Worker) {
        self.host = host
        self.port = port
        self.access = access
        self.worker = worker
    }

    func respond<T: Decodable>(target: ApiTarget) -> Future<T> {
        // TODO: Добавить поддержку HTTP body
        
        let httpRequest = HTTPRequest(method: target.method,
                                      url: url(target: target)!,
                                      headers: target.httpHeaders(access: access))

        let promise = worker.eventLoop.newPromise(T.self)

        Log.info("Sending request:\n\(httpRequest.description)")

        worker.eventLoop.execute { [weak self] in
            self?.send(request: httpRequest).whenSuccess({ (result) in
                promise.succeed(result: result)
            })
        }
        return promise.futureResult
    }

    private func send<T: Decodable>(request: HTTPRequest) -> Future<T> {
        var futureClient: Future<HTTPClient>
        if let existingClient = client {
            Log.info("Using existing HTTP client")
            futureClient = Future<HTTPClient>.map(on: worker, { existingClient })
        } else {
            futureClient = HTTPClient
                .connect(scheme: .https, hostname: host, port: port, on: worker, onError: { [weak self] (error) in
                    Log.info("HTTP Client was down with error: \n\(error.localizedDescription)")
                    Log.error(error.localizedDescription)
                    self?.client = nil
                })
                .do({ (freshClient) in
                    Log.info("Creating new HTTP Client")
                    self.client = freshClient
                })
        }
        return futureClient
            .catch { (error) in
                Log.info("HTTP Client was down with error: \n\(error.localizedDescription)")
                Log.error(error.localizedDescription)
            }
            .then { (client) -> Future<HTTPResponse> in
                Log.info("Sending request to vapor HTTPClient")
                return client.send(request)
            }
            .map(to: T.self) { (response) -> T in
                Log.info("Decoding response from HTTPClient")
                return try self.decode(response: response)
        }
    }

    private func decode<T: Decodable>(response: HTTPResponse) throws -> T {
        ///Temporary workaround for drop current HTTPClient state after each request,
        ///waiting for fixes from Vapor team
        self.client = nil
        if let data = response.body.data {
            return try JSONDecoder().decode(T.self, from: data)
        }
        throw ApiClientError()
    }

    private func url(target: ApiTarget) -> URL? {
        guard let url = URL(string: "https://\(host):\(port)/\(target.path)") else {
            return nil
        }

        switch target.encoding {
        case .url:
            let urlRequest = try? URLEncoding().encode(URLRequest(url: url), with: target.parameters)
            return urlRequest?.url
        default:
            return url
        }
    }
}

protocol ApiTarget {
    var path: String { get }
    var parameters: [String: Any]? { get }
    var method: HTTPMethod { get }
    var encoding: ParametersEncoding { get }
    var headers: [String: String]? { get }
}

enum ParametersEncoding {
    case url
    case json
}

extension ApiTarget {

    func httpHeaders(access: (key: String, value: String)) -> HTTPHeaders {
        var values = (headers ?? [:]) .map { (key, value) -> (String, String) in
            return (key, value)
        }

        values.append(access)
        return HTTPHeaders(values)
    }
}

class ApiClientError: Error {
}
