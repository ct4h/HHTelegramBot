//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 11.06.2024.
//

import Foundation
import FluentSQL

final class OverHoursSQLBuilder: HoursSQLBuilder {
    func sqlRequest(userFilter: UserFilter?, hoursFilter: HoursFilter) -> SQLQueryString? {
        let sqlQueryRaw: String = """
SELECT
    us.lastname,
    us.firstname,
    dep.name as department,
    COALESCE(ROUND(te_total.hours, 2), 0) as total,
    COALESCE(ROUND(te.hours, 2), 0) as hours,
    (
        SELECT cv.value
        FROM custom_values as cv
        WHERE cv.customized_id=us.id AND cv.custom_field_id=35
        LIMIT 1
    ) as telegram_account
FROM users as us
JOIN people_information as pinfo ON us.id=pinfo.user_id
JOIN departments as dep ON pinfo.department_id=dep.id
LEFT JOIN (
    SELECT user_id, SUM(hours) as hours
    FROM time_entries as te
    JOIN issues as iss ON te.issue_id=iss.id
    WHERE %@
    GROUP BY user_id
) as te_total ON us.id=te_total.user_id
LEFT JOIN (
    SELECT user_id, SUM(hours) as hours
    FROM time_entries as te
    JOIN issues as iss ON te.issue_id=iss.id
    WHERE te.activity_id=25 AND %@
    GROUP BY user_id
) as te ON us.id=te.user_id
WHERE us.status=1 AND (te_total.hours > %@.01 OR te.hours > 0)
ORDER BY total DESC
"""
        let hours = hoursFilter.countDays * 8
        let query = String(format: sqlQueryRaw, hoursFilter.condition, hoursFilter.condition, String(hours))
        return .init(stringLiteral: query)
    }
}
