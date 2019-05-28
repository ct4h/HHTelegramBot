import Foundation
import FluentMySQL

final class User: MySQLModel, Hashable {

    static let entity = "users"

    var id: Int?
    var firstname: String
    var lastname: String
    var status: Int

    init(id: Int, firstname: String, lastname: String, status: Int) {
        self.id = id
        self.firstname = firstname
        self.lastname = lastname
        self.status = status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

extension User {

    var name: String {
        return lastname + " " + firstname
    }
}
