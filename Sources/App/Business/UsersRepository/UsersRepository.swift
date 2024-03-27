import Foundation
import Async
import FluentSQL
import MySQL
import LoggerAPI

// TODO: Разобраться с сервисами

final class UsersRepository: ServiceType {
    private let container: Container
    private let customFieldsRepository: CustomFieldsRepository

    static func makeService(for container: Container) throws -> UsersRepository {
        return UsersRepository(
            container: container,
            customFieldsRepository: try container.make()
        )
    }

    init(container: Container, customFieldsRepository: CustomFieldsRepository) {
        self.container = container
        self.customFieldsRepository = customFieldsRepository
    }

    func users(request: UsersRequest) -> Future<[UserResponse]> {
        let usersFuture = container.withPooledConnection(to: .mysql) { request.all(on: $0) }
        let customFieldsFuture = customFieldsRepository.customFields(request: request)

        return map(usersFuture, customFieldsFuture) { (users, customFields) -> [UserResponse] in
            var result: [UserResponse] = []

            users.forEach { (userData) in
                let ((user, emailAddress), department) = userData
                
                if let userId = user.id, let fields = customFields[userId] {
                    result.append(UserResponse(user: user, email: emailAddress.address, department: department, fields: fields))
                }
            }

            return result
        }
    }
}
