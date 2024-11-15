----------------------------------------------------------------------------------------------------------
-------------------- Which class times and days have the highest attendance? -----------------------------
----------------------------------------------------------------------------------------------------------
WITH class_attendee_counts AS(
	SELECT class_id, COUNT(customer_id) num_of_attendees
	FROM attendance
	WHERE final_status = 'Confirmed'
	GROUP BY 1)
SELECT cs.time, TO_CHAR(date, 'Day') AS day_of_week,
	ROUND(SUM(num_of_attendees)/SUM(capacity) * 100, 2) AS attendance_rate
FROM class_attendee_counts cac
JOIN class_schedule cs
	ON cac.class_id = cs.class_id
GROUP BY 1,2
ORDER BY 3 DESC; 
----------------------------------------------------------------------------------------------------------
-------------------------- What are the most popular types of classes? -----------------------------------
----------------------------------------------------------------------------------------------------------
WITH class_attendee_counts AS(
	SELECT class_id, COUNT(customer_id) num_of_attendees
	FROM attendance
	WHERE final_status = 'Confirmed'
	GROUP BY 1)
--
SELECT class_type,
	COUNT(cs.class_id) num_of_classes,
	SUM(num_of_attendees) ytd_num_of_attendees, 
	SUM(capacity) ytd_capacity,
	ROUND(SUM(num_of_attendees)/SUM(capacity) * 100, 2) AS attendance_rate
FROM class_attendee_counts cac
JOIN class_schedule cs
	ON cac.class_id = cs.class_id
GROUP BY 1
ORDER BY 5 DESC;
----------------------------------------------------------------------------------------------------------
------------------ Are there trends in class popularity by season or time of year? -----------------------
----------------------------------------------------------------------------------------------------------
WITH attendance_count AS (
	SELECT a.class_id, class_type, COUNT(customer_id) total_attendees
	FROM attendance a
	JOIN class_schedule cs
		ON a.class_id = cs.class_id
	WHERE final_status = 'Confirmed'
	GROUP BY 1,2
),
	seasons AS (
	SELECT 
    *,
    CASE
        WHEN EXTRACT(MONTH FROM cs.Date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM cs.Date) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(MONTH FROM cs.Date) IN (6, 7, 8) THEN 'Summer'
        WHEN EXTRACT(MONTH FROM cs.Date) IN (9, 10, 11) THEN 'Fall'
    END AS Season
	FROM class_schedule cs
)
SELECT class_type, season,
	SUM(total_attendees) num_of_attendees, -- sum the attendees
	SUM(capacity) max_capacity, -- sum the capacity
	ROUND(SUM(total_attendees)/SUM(capacity) * 100,2) AS attendance_rate -- calculate the attendance rate
FROM (
	SELECT ac.class_id, ac.class_type, total_attendees, capacity, season
	FROM attendance_count ac
	JOIN seasons s
		ON ac.class_id = s.class_id
		)
GROUP BY 1,2
ORDER BY 2,5 DESC;
----------------------------------------------------------------------------------------------------------
-------------------------------------- What is the class fill rate? --------------------------------------
----------------------------------------------------------------------------------------------------------
WITH class_attendance_count AS 
(	SELECT class_id, 
		COUNT(customer_id) num_of_attendees
	FROM attendance
	WHERE final_status = 'Confirmed'
	GROUP BY class_id
), class_fill_rate AS 
(	SELECT class_type, 
		SUM(num_of_attendees) total_attendance, 
		SUM(capacity) max_attendance, 
		COUNT(cs.class_id) num_of_classes,
		ROUND(SUM(num_of_attendees)/SUM(capacity) * 100, 2) AS fill_rate
	FROM class_attendance_count cac
	RIGHT JOIN class_schedule cs -- use a right join just in case there are classes with 0 people
		ON cac.class_id = cs.class_id
	GROUP BY 1
)
SELECT ROUND(AVG(fill_rate),2)
FROM class_fill_rate;
----------------------------------------------------------------------------------------------------------
----------------------- Are certain classes consistently under- or over-booked? --------------------------
----------------------------------------------------------------------------------------------------------
WITH class_count AS (
    SELECT 
        class_id, 
        COUNT(customer_id) AS num_of_attendees
    FROM attendance
    WHERE final_status = 'Confirmed'
    GROUP BY class_id
),
waitlist_count AS (
    SELECT 
        class_id, 
        COUNT(final_status) AS final_waitlist_size
    FROM attendance
    WHERE final_status = 'Waitlist'
    GROUP BY class_id
),
class_fill_stats AS (
    SELECT 
        cc.class_id, 
        cs.class_type, 
        cc.num_of_attendees, 
        wc.final_waitlist_size,
        CASE
            WHEN num_of_attendees <= 5 THEN 'Underbooked'
            WHEN final_waitlist_size >= 1 THEN 'Overbooked'
            ELSE 'Properly Booked'
        END AS class_fill_status
    FROM 
        class_count cc
    LEFT JOIN 
        waitlist_count wc 
        ON cc.class_id = wc.class_id
    JOIN  
        class_schedule cs
    ON cc.class_id = cs.class_id
),
classtype_fillnum AS (
    SELECT 
        class_type, 
        class_fill_status, 
        COUNT(class_fill_status) AS fill_status_num
    FROM class_fill_stats
    GROUP BY class_type, class_fill_status
)
SELECT 
    class_type, 
    class_fill_status, 
    fill_status_num,
    -- Window function to get the total count of all fill statuses per class_type
    SUM(fill_status_num) OVER (PARTITION BY class_type) AS total_fill_status_num,
    -- Calculate the proportion (percentage) of each fill_status_num within the class_type
    ROUND((fill_status_num * 1.0) / SUM(fill_status_num) OVER (PARTITION BY class_type) * 100,2) AS fill_status_avg
FROM classtype_fillnum
ORDER BY 5 DESC;
----------------------------------------------------------------------------------------------------------
-------------------------------- What is the average class waitlist size? --------------------------------
----------------------------------------------------------------------------------------------------------
WITH avg_waitlist_classtype AS (SELECT class_type,
	ROUND(AVG(final_waitlist_size),2) AS avg_waitlist_size
FROM (	SELECT a.class_id, class_type,
			COUNT(final_status) final_waitlist_size
		FROM attendance a
		JOIN class_schedule cs
			ON a.class_id = cs.class_id
		WHERE final_status = 'Waitlist'
		GROUP BY 1,2
)
GROUP BY 1)
SELECT ROUND(AVG(avg_waitlist_size),0)
FROM avg_waitlist_classtype;
---
SELECT class_type,
	ROUND(AVG(final_waitlist_size),0)
FROM (	SELECT a.class_id, class_type,
			COUNT(final_status) final_waitlist_size
		FROM attendance a
		JOIN class_schedule cs
			ON a.class_id = cs.class_id
		WHERE final_status = 'Waitlist'
		GROUP BY 1,2
)
GROUP BY 1;