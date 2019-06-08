//
//  HoursGroupsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Vapor
import FluentSQL

class HoursGroupsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursDepartmentRequest
    let container: Container

    init(chatID: Int64, parentRequest: HoursDepartmentRequest, container: Container) {
        self.chatID = chatID
        self.parentRequest = parentRequest
        self.container = container
    }

    var request: Future<InlineCommandsRequest> {
        let parentRequest = self.parentRequest
        let title = self.title

        return groups(customFieldName: parentRequest.department).map{ (groups) -> InlineCommandsRequest in
            let values = groups.map { (group) -> InlineButtonData in
                let query = HoursGroupRequest(departmentRequest: parentRequest, group: group).query
                return InlineButtonData(title: group, query: query)
            }

            return InlineCommandsRequest(context: parentRequest.context,
                                         title: title,
                                         values: values)
        }
    }
}

private extension HoursGroupsRequestFactory {

    func groups(customFieldName: String) -> Future<[String]> {
        return container.requestCachedConnection(to: .mysql)
            .flatMap { (connection) -> EventLoopFuture<[CustomField]> in
                let builder = CustomField.query(on: connection)
                    .filter(\.name == customFieldName)
                return builder.all()
            }
            .map{ (customFields) -> [String] in
                guard let customField = customFields.first else {
                    return []
                }

                return customField.values
            }
    }

    var title: String {
        return "Выбери группу пользователей:"
    }
}
