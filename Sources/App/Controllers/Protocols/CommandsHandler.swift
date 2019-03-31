//
//  CommandsHandler.swift
//  App
//
//  Created by basalaev on 02/03/2019.
//

import Foundation
import Telegrammer

protocol CommandsHandler {
    var handlers: [Handler] { get }
}
