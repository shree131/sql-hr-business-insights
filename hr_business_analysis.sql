-- ============================================
-- B. BUSINESS PROBLEM: Help HR track salaries more easily using SQL views 
-- OBJECTIVE: Create accessible views to track employee salaries and department relationships
-- ============================================

-- View: Current salaries of department managers
CREATE VIEW manager_salaries AS
SELECT 
    e.emp_no, 
    s.salary, 
    d.dept_no, 
    d.dept_name
FROM salaries AS s
LEFT JOIN employees AS e ON e.emp_no = s.emp_no
LEFT JOIN dept_manager AS dm ON dm.emp_no = e.emp_no
LEFT JOIN departments AS d ON d.dept_no = dm.dept_no
WHERE s.to_date = '9999-01-01' AND d.dept_no IS NOT NULL;

-- View: Average salary per department
CREATE VIEW dept_avg_salaries AS
SELECT 
    d.dept_name, 
    ROUND(AVG(s.salary), 2) AS avg_salary
FROM salaries AS s
LEFT JOIN employees AS e ON s.emp_no = e.emp_no
LEFT JOIN dept_emp AS de ON de.emp_no = e.emp_no
LEFT JOIN departments AS d ON d.dept_no = de.dept_no
WHERE s.to_date = '9999-01-01'
GROUP BY d.dept_name;

-- Clean up department names by removing surrounding quotes (if any)
UPDATE departments
SET dept_name = SUBSTRING(dept_name, 2, LENGTH(dept_name) - 2)
WHERE dept_name LIKE '"%"';

-- View: Department manager salaries with comparison to department average
CREATE VIEW manager_salary_vs_avg AS
SELECT 
    d.dept_name, 
    CONCAT(e.first_name, ' ', e.last_name) AS manager_name, 
    s.salary AS manager_salary, 
    es.avg_salary
FROM dept_manager AS dm
INNER JOIN employees AS e ON dm.emp_no = e.emp_no
LEFT JOIN departments AS d ON dm.dept_no = d.dept_no
LEFT JOIN salaries AS s ON e.emp_no = s.emp_no
LEFT JOIN (
    SELECT 
        d.dept_name, 
        ROUND(AVG(s.salary), 2) AS avg_salary
    FROM salaries AS s
    LEFT JOIN employees AS e ON s.emp_no = e.emp_no
    LEFT JOIN dept_emp AS de ON de.emp_no = e.emp_no
    LEFT JOIN departments AS d ON d.dept_no = de.dept_no
    WHERE s.to_date = '9999-01-01'
    GROUP BY d.dept_name
) AS es ON es.dept_name = d.dept_name
WHERE dm.to_date = '9999-01-01' AND s.to_date = '9999-01-01';

-- ============================================
-- C. BUSINESS PROBLEM: Segment customers by rental return habits for dashboard use
-- OBJECTIVE: Build views to categorize customers based on return times since 2005
-- ============================================

-- View: Days taken to return each movie
CREATE VIEW movie_return_times AS
SELECT 
    rental_id, 
    customer_id, 
    rental_date, 
    return_date,
    DATEDIFF(
        IF(return_date IS NULL, CURRENT_DATE, return_date), 
        rental_date
    ) AS return_time
FROM rental;

-- View: Average return time per customer since 2005
CREATE VIEW customer_avg_return_times AS
SELECT 
    customer_id,
    TRUNCATE(AVG(return_time), 0) AS avg_return_time
FROM movie_return_times
WHERE YEAR(rental_date) >= 2005
GROUP BY customer_id;

-- View: Final dashboard view with rating categories
CREATE VIEW customer_dashboard AS
SELECT 
    c.*, 
    rt.avg_return_time,
    CASE 
        WHEN avg_return_time <= 7 THEN 'GOOD'
        WHEN avg_return_time <= 30 THEN 'FAIR'
        ELSE 'BAD'
    END AS customer_rating
FROM customer_avg_return_times AS rt
LEFT JOIN customer AS c ON rt.customer_id = c.customer_id;

-- ============================================
-- D. BUSINESS PROBLEM: Support company valuation with customer insights
-- OBJECTIVE: Calculate DVD rentals, durations, and customer distribution by district
-- ============================================

-- View: Average rental duration per customer
CREATE VIEW rental_duration AS
SELECT 
    customer_id, 
    AVG(DATEDIFF(return_date, rental_date)) AS avg_rental_duration
FROM rental
GROUP BY customer_id;

-- View: Total DVDs rented by customer and district
CREATE VIEW total_dvds AS
SELECT 
    c.customer_id, 
    a.district, 
    COUNT(inventory_id) AS total_dvds_rented
FROM customer AS c 
INNER JOIN address AS a ON c.address_id = a.address_id
INNER JOIN rental AS r ON r.customer_id = c.customer_id
GROUP BY c.customer_id, a.district;

-- View: Valuation report summary by district
CREATE VIEW valuation_report AS
SELECT 
    a.district, 
    AVG(rd.avg_rental_duration) AS avg_rental_duration, 
    SUM(td.total_dvds_rented) AS total_dvds_rented, 
    COUNT(c.customer_id) AS total_customers
FROM rental_duration AS rd
INNER JOIN customer AS c ON c.customer_id = rd.customer_id
INNER JOIN address AS a ON a.address_id = c.address_id
INNER JOIN total_dvds AS td ON td.customer_id = c.customer_id
GROUP BY a.district
ORDER BY a.district;

-- ============================================
-- E. BUSINESS PROBLEM: Provide labor cost indicators for cost optimization
-- OBJECTIVE: Join salary and department data to support decisions on labor cost reduction
-- ============================================

-- View: Current salaries based on future-dated contracts
CREATE VIEW current_salaries AS
SELECT emp_no, salary
FROM salaries
WHERE to_date > CURRENT_DATE;

-- View: Current department assignments
CREATE VIEW current_dept_emp AS
SELECT emp_no, dept_no
FROM dept_emp
WHERE to_date > CURRENT_DATE;

-- Query: Summarize salary by department
-- (This is a standalone SELECT, not a view)
SELECT 
    d.dept_no, 
    d.dept_name, 
    SUM(cs.salary) AS total_salary
FROM current_dept_emp AS de 
INNER JOIN departments AS d ON de.dept_no = d.dept_no
INNER JOIN current_salaries AS cs ON cs.emp_no = de.emp_no
GROUP BY d.dept_no, d.dept_name;
