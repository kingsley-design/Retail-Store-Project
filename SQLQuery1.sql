USE Projects

-- Returns all rows from the 'Orders (Raw)$' table where Order_Date is in dd/MM/yyyy format 

SELECT Order_ID, Order_Date
FROM ['Orders (Raw)$']
WHERE Order_Date LIKE '%/%'
  AND TRY_CONVERT(date, Order_Date, 103) IS NOT NULL
  AND TRY_CONVERT(date, Order_Date, 120) IS NULL;

-- Convert Order_Date from dd/MM/yyyy to yyyy-MM-dd format for rows that match the specified conditions
UPDATE ['Orders (Raw)$']
SET Order_Date = CONVERT(varchar(10), TRY_CONVERT(date, Order_Date, 103), 120)
WHERE Order_Date LIKE '%/%'
  AND TRY_CONVERT(date, Order_Date, 103) IS NOT NULL
  AND TRY_CONVERT(date, Order_Date, 120) IS NULL;
 
/* 
Now the above first code will return no rows as all the Order_Date values in the 'Orders (Raw)$' table 
that were in dd/MM/yyyy (European) format have been converted to yyyy-MM-dd (ISO) format.
*/

SELECT COUNT(*) AS Total_Null_Ship_Dates
FROM ['Orders (Raw)$']
WHERE Ship_Date = '' OR Ship_Date IS NULL;

-- Percentage of rows in the 'Orders (Raw)$' table where Ship_Date is either NULL or an empty string
SELECT 
  CAST(100.0 * SUM(CASE WHEN Ship_Date IS NULL 
  OR LTRIM(RTRIM(Ship_Date)) = '' THEN 1 ELSE 0 END) 
  / COUNT(*) AS DECIMAL(5,2)) AS NullShipDatePercent
FROM ['Orders (Raw)$'];

-- Number of rows in the 'Orders (Raw)$' table where Ship_Date is before Order_Date, excluding NULL values
SELECT COUNT(*) AS ShipDatesBeforeOrderDate
FROM ['Orders (Raw)$']
WHERE 
  Ship_Date IS NOT NULL 
  AND Order_Date IS NOT NULL
  AND TRY_CONVERT(date, Ship_Date, 120) < TRY_CONVERT(date, Order_Date, 120);

SELECT
    AVG(DATEDIFF(day,
          TRY_CAST(Order_Date AS DATE),
          TRY_CAST(Ship_Date  AS DATE))) AS avg_lead_days,
    MIN(DATEDIFF(day,
          TRY_CAST(Order_Date AS DATE),
          TRY_CAST(Ship_Date  AS DATE))) AS min_lead_days,
    MAX(DATEDIFF(day,
          TRY_CAST(Order_Date AS DATE),
          TRY_CAST(Ship_Date  AS DATE))) AS max_lead_days
FROM  ['Orders (Raw)$']
WHERE TRY_CAST(Ship_Date  AS DATE) IS NOT NULL
  AND TRY_CAST(Order_Date AS DATE) IS NOT NULL
  AND TRY_CAST(Ship_Date  AS DATE)
   >= TRY_CAST(Order_Date AS DATE);

SELECT TOP 100 *
FROM ['Orders (Raw)$']

SELECT 
    Order_Date,
    Ship_Date 
FROM ['Orders (Raw)$']
WHERE 
  Ship_Date IS NOT NULL 
  AND Order_Date IS NOT NULL
  AND TRY_CONVERT(date, Ship_Date, 120) < TRY_CONVERT(date, Order_Date, 120);

-- Identify potential data entry errors where Ship_Date is before Order_Date, and assess whether the dates might have been swapped or if they are implausible values. This query calculates the number of days between the two dates and categorizes the records accordingly.
SELECT
    Order_ID,
    Order_Date,
    Ship_Date,
    DATEDIFF(day,
        TRY_CAST(Ship_Date  AS DATE),
        TRY_CAST(Order_Date AS DATE)) AS days_apart,
    CASE
        WHEN TRY_CAST(Ship_Date AS DATE)
             BETWEEN DATEADD(year,-1, TRY_CAST(Order_Date AS DATE))
                 AND TRY_CAST(Order_Date AS DATE)
            THEN 'plausible_swap'
        ELSE 'suspicious_value'
    END AS swap_assessment
FROM   ['Orders (Raw)$']
WHERE  TRY_CAST(Ship_Date  AS DATE) IS NOT NULL
  AND  TRY_CAST(Order_Date AS DATE) IS NOT NULL
  AND  TRY_CAST(Ship_Date  AS DATE) < TRY_CAST(Order_Date AS DATE)
ORDER BY days_apart DESC;

-- Query to set Ship_Date to NULL for records where Ship_Date is before Order_Date, as these are likely data entry errors. This will help in cleaning the data for more accurate analysis.
UPDATE ['Orders (Raw)$']
SET Ship_Date = NULL
WHERE Ship_Date IS NOT NULL 
  AND Order_Date IS NOT NULL
  AND TRY_CONVERT(date, Ship_Date, 120) < TRY_CONVERT(date, Order_Date, 120);

SELECT *
FROM ['Orders (Raw)$']
ORDER BY TRY_CONVERT(date, Order_Date, 120);

SELECT DISTINCT
    Customer_ID,
    City
FROM ['Orders (Raw)$']
ORDER BY Customer_ID;

-- Customers that have orders delivered to more than one city
    Customer_ID,
    COUNT(DISTINCT City) AS CityCount,
    STRING_AGG(City, ', ') AS Cities
FROM ['Orders (Raw)$']
WHERE Customer_ID IS NOT NULL AND Customer_ID <> 'N/A'
GROUP BY Customer_ID
HAVING COUNT(DISTINCT City) > 1
ORDER BY CityCount DESC, Customer_ID;

-- Trim whitespace from Region column
UPDATE ['Orders (Raw)$']
SET Region = LTRIM(RTRIM(Region))
WHERE Region IS NOT NULL;

-- Identify rows where Sales_Rep is NULL or contains only whitespace, which may indicate missing or incomplete data
SELECT *
FROM ['Orders (Raw)$']
WHERE Sales_Rep IS NULL OR LTRIM(RTRIM(Sales_Rep)) = '';

SELECT DISTINCT
    Order_ID,
    Order_Date,
    Customer_ID,
    Sales_Rep,
    Product_Name
FROM ['Orders (Raw)$']
ORDER BY Order_Date;

/* This returns all rows from the 'Orders (Raw)$' table where there are duplicate entries based on Order_ID, Order_Date, Customer_ID, and Product_Name, 
but only if those duplicates have the same Sales_Rep. This can help to identify potential data entry issues or cases where some Sales representative names is not captured (IS NULL or blank).
*/
SELECT 
    Order_ID,
    Order_Date,
    Customer_ID,
    Product_Name,
    Sales_Rep
FROM ['Orders (Raw)$']
WHERE EXISTS (
    SELECT 1
    FROM ['Orders (Raw)$'] t2
    WHERE 
        t2.Order_ID = ['Orders (Raw)$'].Order_ID
        AND t2.Order_Date = ['Orders (Raw)$'].Order_Date
        AND t2.Customer_ID = ['Orders (Raw)$'].Customer_ID
        AND t2.Product_Name = ['Orders (Raw)$'].Product_Name
    GROUP BY t2.Order_ID, t2.Order_Date, t2.Customer_ID, t2.Product_Name
    HAVING COUNT(DISTINCT t2.Sales_Rep) = 1 AND COUNT(*) > 1
)
ORDER BY Order_ID, Order_Date, Customer_ID, Product_Name;

-- Returns Sales representative names for rows in the 'Orders (Raw)$' table where Sales_Rep is NULL or blank, by looking for duplicate entries based on Order_ID, Order_Date, Customer_ID, and Product_Name that have a non-NULL and non-blank Sales_Rep value.
UPDATE t
SET t.Sales_Rep = s.Sales_Rep
FROM ['Orders (Raw)$'] t
INNER JOIN (
    SELECT 
        Order_ID, Order_Date, Customer_ID, Product_Name, MAX(Sales_Rep) AS Sales_Rep
    FROM ['Orders (Raw)$']
    WHERE Sales_Rep IS NOT NULL AND LTRIM(RTRIM(Sales_Rep)) <> ''
    GROUP BY Order_ID, Order_Date, Customer_ID, Product_Name
) s
ON t.Order_ID = s.Order_ID
   AND t.Order_Date = s.Order_Date
   AND t.Customer_ID = s.Customer_ID
   AND t.Product_Name = s.Product_Name
WHERE t.Sales_Rep IS NULL OR LTRIM(RTRIM(t.Sales_Rep)) = '';

SELECT *
FROM ['Orders (Raw)$']
WHERE Sales_Rep IS NULL OR LTRIM(RTRIM(Sales_Rep)) = '';

