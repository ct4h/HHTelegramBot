//
//  HoursDepartmentsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Vapor
import FluentSQL
import LoggerAPI

class HoursDepartmentsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursDepartmentsRequest
    let container: Container

    init(chatID: Int64, parentRequest: HoursDepartmentsRequest,container: Container) {
        self.chatID = chatID
        self.parentRequest = parentRequest
        self.container = container
    }

    var request: Future<InlineCommandsRequest> {
        let parentRequest = self.parentRequest
        let title = self.title

        return customFields.map { (customFields) -> InlineCommandsRequest in
            Log.info("Extract fields \(customFields)")
            let values = customFields.map { (customField) -> InlineButtonData in
                let query = HoursDepartmentRequest(departmentsRequest: parentRequest, department: customField).query
                return InlineButtonData(title: customField, query: query)
            }

            return InlineCommandsRequest(context: parentRequest.context,
                                         title: title,
                                         values: values)
        }
    }
}

private extension HoursDepartmentsRequestFactory {

    var customFields: Future<[String]> {
        return container.newConnection(to: .mysql)
            .flatMap { (connection) -> EventLoopFuture<[CustomField]> in
                Log.info("Make connection")

                let builder = CustomField.query(on: connection)
                    .filter(\CustomField.type == "UserCustomField")
                    .filter(\CustomField.field_format == "list")
                    .sort(\.name, .ascending)

                return builder.all()
            }.map { $0.map { $0.name } }
    }

    var title: String {
        return "Выбери департамент:"
    }
}
