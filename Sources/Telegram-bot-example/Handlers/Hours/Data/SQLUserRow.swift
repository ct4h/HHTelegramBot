//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

struct SQLUserRow: Decodable {
    let lastname: String?
    let firstname: String?
    let department: String?
    let total: Double?
    let hours: Double
    let telegram_account: String?
    let is_hh_employee: String?
}
