//
//  File.swift
//
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation
import FluentSQL

final class DailyHoursSQLBuilder: HoursSQLBuilder {
    func sqlRequest(userFilter: UserFilter?, hoursFilter: HoursFilter) -> SQLQueryString? {
        guard let userFilter else {
            return nil
        }
        
        let sqlQueryRaw: String = """
SELECT
    us.lastname,
    us.firstname,
    COALESCE(ROUND(te.hours, 2), 0) as hours,
    (
        SELECT cv.value
        FROM custom_values as cv
        WHERE cv.customized_id=us.id AND cv.custom_field_id=35
        LIMIT 1
    ) as telegram_account
FROM users as us
%@
LEFT JOIN (
    SELECT user_id, SUM(hours) as hours
    FROM time_entries
    WHERE %@
    GROUP BY user_id
) as te ON us.id=te.user_id
WHERE us.status=1 AND %@
ORDER BY us.lastname
"""
        
        let joins = userFilter.joins.joined(separator: " ")
        let filterCondition = userFilter.condition.joined(separator: " AND ")
        
        let query = String(format: sqlQueryRaw, joins, hoursFilter.condition, filterCondition)
        return .init(stringLiteral: query)
    }
}
