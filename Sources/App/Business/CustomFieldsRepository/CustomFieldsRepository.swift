import Foundation
import Async
import FluentSQL
import MySQL

final class CustomFieldsRepository: ServiceType {
    private let container: Container

    static func makeService(for container: Container) throws -> CustomFieldsRepository {
        return CustomFieldsRepository(container: container)
    }

    init(container: Container) {
        self.container = container
    }

    func customFields(request: CustomFieldsRequest) -> Future<[Int: [CustomFieldsResponse]]> {
        return container.withPooledConnection(to: .mysql) { request.all(on: $0) }
            .map { (response) -> [Int: [CustomFieldsResponse]] in
                var result: [Int: [CustomFieldsResponse]] = [:]

                for (customField, customValue) in response {
                    var field = result[customValue.customized_id] ?? []
                    field.append(CustomFieldsResponse(name: customField.name, value: customValue.value))
                    result[customValue.customized_id] = field
                }

                return result
        }
    }
}
