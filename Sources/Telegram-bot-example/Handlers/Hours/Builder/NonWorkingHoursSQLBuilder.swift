//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation
import FluentSQL

final class NonWorkingHoursSQLBuilder: HoursSQLBuilder {
    func sqlRequest(userFilter: UserFilter?, hoursFilter: HoursFilter) -> SQLQueryString? {
        let sqlQueryRaw: String = """
SELECT
    us.lastname,
    us.firstname,
    dep.name as department,
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
JOIN (
    SELECT user_id, SUM(hours) as hours
    FROM time_entries as te
    JOIN issues as iss ON te.issue_id=iss.id
    WHERE (te.activity_id=37 OR LOWER(te.comments) LIKE '%протой%' OR LOWER(te.comments) LIKE '%протои%' OR LOWER(iss.subject) LIKE '%протой%' OR LOWER(iss.subject) LIKE '%протои%') AND %@
    GROUP BY user_id
) as te ON us.id=te.user_id
WHERE us.status=1
ORDER BY hours DESC
"""
        
        let query = String(format: sqlQueryRaw, hoursFilter.condition)
        return .init(stringLiteral: query)
    }
}

