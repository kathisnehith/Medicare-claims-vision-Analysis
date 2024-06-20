-- Selecting top 200 records from each table
SELECT TOP 200 * FROM demograp;
SELECT TOP 200 * FROM stats;
SELECT TOP 200 * FROM health;
SELECT TOP 200 * FROM geolocation;

-- Creating a procedure to check for nulls
CREATE PROCEDURE CheckForNulls
    @TableName NVARCHAR(128),
    @ColumnName NVARCHAR(128)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = N'SELECT COUNT(*) FROM ' + QUOTENAME(@TableName) + 
               ' WHERE ' + QUOTENAME(@ColumnName) + ' IS NULL';
    EXEC sp_executesql @SQL;
END;

-- Creating a procedure to check for duplicates
CREATE PROCEDURE CheckForDuplicates
    @TableName NVARCHAR(128),
    @ColumnName NVARCHAR(128)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = N'SELECT ' + QUOTENAME(@ColumnName) + ', COUNT(*) as CountOf ' + 
               'FROM ' + QUOTENAME(@TableName) + 
               ' GROUP BY ' + QUOTENAME(@ColumnName) + 
               ' HAVING COUNT(*) > 1';
    EXEC sp_executesql @SQL;
END;

-- Executing the procedures
EXEC CheckForDuplicates 'demograp', 'RaceEthnicity';
EXEC CheckForNulls 'demograp', 'RaceEthnicity';
EXEC CheckForNulls 'stats', 'Data_Value_Type';
EXEC CheckForNulls 'geolocation', 'GeoLocation'; -- has null values
EXEC CheckForNulls 'geolocation', 'Location_Description';

-- Selecting distinct years and topics
SELECT DISTINCT Year FROM stats;
SELECT DISTINCT Topic FROM health;

-- Selecting top 200 records from health
SELECT TOP 200 * FROM health;

-- Checking for nulls in health
EXEC CheckForNulls 'health', 'RiskFactor';

-- Creating views for the tables for performance optimization
CREATE VIEW demographics_view AS
SELECT 
    [Year],
    Age,
    Gender,
    RaceEthnicity
FROM demograp;

CREATE VIEW health_view AS
SELECT 
    [Year],
    Topic,
    Category,
    Question,
    Response,
    RiskFactor,
    RiskFactorResponse
FROM health;

CREATE VIEW location_view AS
SELECT 
    LocationAbbr,
    Location_Description,
    GeographicLevel,
    GeoLocation
FROM geolocation;

CREATE VIEW statistics_view AS
SELECT 
    [Year],
    Data_Value,
    Low_Confidence_limit,
    High_Confidence_Limit
FROM stats;

-- Executing the view
SELECT TOP 200 * FROM health_view;

-- Insight analysis
-- What is the prevalence of different eye health conditions across age groups
SELECT d.Age, h.Category --AVG(s.Data_Value) as avg_prevalence
FROM demographics_view d
JOIN health_view h ON d.[Year] = h.Year
JOIN statistics_view s ON d.[Year] = s.Year
WHERE h.Topic = 'Eye Health Conditions'
GROUP BY d.Age, h.Category
ORDER BY d.Age DESC;

-- How does the prevalence of diabetic eye diseases vary across different states
SELECT l.Location_Description, AVG(s.Data_Value) as avg_prevalence
FROM location_view l
JOIN health_view h ON l.Year = h.Year
JOIN statistics_view s ON l.Year = s.Year
WHERE h.Category = 'Diabetic Eye Diseases' AND l.GeographicLevel = 'State'
GROUP BY l.Location_Description
ORDER BY avg_prevalence DESC;

-- What is the relationship between age and the likelihood of having a vision correction claim
SELECT d.Age, AVG(s.Data_Value) as avg_claim_rate
FROM demographics_view d
JOIN health_view h ON d.Year = h.Year
JOIN statistics_view s ON d.Year = s.Year
WHERE h.Category = 'Vision Correction' AND h.Question = 'Percentage of people who had a vision correction visit or supplies claim'
GROUP BY d.Age
ORDER BY d.Age;

-- How does the prevalence of glaucoma differ between males and females across different race/ethnicity groups
SELECT d.Gender, d.RaceEthnicity, AVG(s.Data_Value) as avg_prevalence
FROM demographics_view d
JOIN health_view h ON d.Year = h.Year
JOIN statistics_view s ON d.Year = s.Year
WHERE h.Category = 'Glaucoma'
GROUP BY d.Gender, d.RaceEthnicity
ORDER BY avg_prevalence DESC;

-- What is the trend of eye exam rates over time for different age groups
SELECT d.Year, d.Age, AVG(s.Data_Value) as avg_exam_rate
FROM demographics_view d
JOIN health_view h ON d.Year = h.Year
JOIN statistics_view s ON d.Year = s.Year
WHERE h.Category = 'Eye Exams' AND h.Question = 'Proportion of patients who had an eye exam in selected year'
GROUP BY d.Year, d.Age
ORDER BY d.Year, d.Age;

-- Analysis of the relationship between diabetes and various eye conditions
SELECT 
    h.Category as eye_condition,
    AVG(CASE WHEN h.RiskFactor = 'Diabetes' THEN s.Data_Value ELSE NULL END) as avg_prevalence_with_diabetes,
    AVG(CASE WHEN h.RiskFactor != 'Diabetes' OR h.RiskFactor IS NULL THEN s.Data_Value ELSE NULL END) as avg_prevalence_without_diabetes,
    COUNT(DISTINCT CASE WHEN h.RiskFactor = 'Diabetes' THEN s.Year END) as diabetes_sample_count,
    COUNT(DISTINCT CASE WHEN h.RiskFactor != 'Diabetes' OR h.RiskFactor IS NULL THEN s.Year END) as non_diabetes_sample_count
FROM health_view h
JOIN statistics_view s ON h.Year = s.Year
WHERE h.Topic = 'Eye Health Conditions'
GROUP BY h.Category
HAVING diabetes_sample_count > 0 AND non_diabetes_sample_count > 0
ORDER BY (avg_prevalence_with_diabetes - avg_prevalence_without_diabetes) DESC;

-- Trend analysis of cataract surgery rates across different age groups over time
SELECT 
    d.Year,
    d.Age,
    AVG(s.Data_Value) as avg_surgery_rate,
    AVG(s.Low_Confidence_limit) as avg_low_ci,
    AVG(s.High_Confidence_Limit) as avg_high_ci
FROM demographics_view d
JOIN health_view h ON d.Year = h.Year
JOIN statistics_view s ON d.Year = s.Year
WHERE h.Category = 'Cataract Surgery' 
    AND h.Question = 'Percentage of people with diagnosed cataract who had a treatment claim'
    AND h.Response = 'Cataract surgery'
GROUP BY d.Year, d.Age
ORDER BY d.Year, CASE
    WHEN d.Age = 'All ages' THEN 1
    WHEN d.Age = '18-39 years' THEN 2
    WHEN d.Age = '40-64 years' THEN 3
    WHEN d.Age = '65-84 years' THEN 4
    WHEN d.Age = '85 years and older' THEN 5
    ELSE 6
END;

-- Analyzing the correlation between the frequency of eye exams and the prevalence of 
-- advanced eye conditions in different locations
SELECT 
    e.exam_frequency_group,
    AVG(s.Data_Value) as avg_advanced_condition_prevalence,
    COUNT(DISTINCT l.LocationID) as location_count
FROM (
    SELECT 
        h.Year, 
        l.LocationID,
        CASE 
            WHEN AVG(s.Data_Value) >= 75 THEN 'High exam frequency'
            WHEN AVG(s.Data_Value) >= 50 THEN 'Medium exam frequency'
            ELSE 'Low exam frequency'
        END as exam_frequency_group
    FROM health_view h
    JOIN statistics_view s ON h.Year = s.Year
    JOIN location_view l ON h.Year = l.Year
    WHERE h.Category = 'Eye Exams' 
    AND h.Question = 'Proportion of patients who had an eye exam in selected year'
    GROUP BY h.Year, l.LocationID
) e
JOIN health_view h ON e.Year = h.Year
JOIN statistics_view s ON h.Year = s.Year AND e.LocationID = s.LocationID
JOIN location_view l ON e.Year = l.Year AND e.LocationID = l.LocationID
WHERE h.Category IN ('Glaucoma', 'Age Related Macular Degeneration', 'Diabetic Eye Diseases')
AND h.Question LIKE '%vision threatening%'
GROUP BY e.exam_frequency_group
ORDER BY avg_advanced_condition_prevalence DESC;
