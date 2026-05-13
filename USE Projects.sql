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

-- Returns all rows from the 'Orders (Raw)$' table where Sales_Rep is 'TBD'.
SELECT *
FROM ['Orders (Raw)$']
WHERE LTRIM(RTRIM(Sales_Rep)) = 'TBD';

-- 1) How many TBDs?
SELECT COUNT(*) AS TBD_Count
FROM ['Orders (Raw)$']
WHERE UPPER(LTRIM(RTRIM(Sales_Rep))) = 'TBD';

-- 2) Standardize TBD -> NULL
UPDATE ['Orders (Raw)$']
SET Sales_Rep = NULL
WHERE UPPER(LTRIM(RTRIM(Sales_Rep))) = 'TBD';

-- 3) Re-run your backfill, but now it will also fill former TBDs
UPDATE t
SET t.Sales_Rep = s.Sales_Rep
FROM ['Orders (Raw)$'] t
INNER JOIN (
    SELECT Order_ID, Order_Date, Customer_ID, Product_Name, MAX(Sales_Rep) AS Sales_Rep
    FROM ['Orders (Raw)$']
    WHERE Sales_Rep IS NOT NULL AND LTRIM(RTRIM(Sales_Rep)) <> ''
    GROUP BY Order_ID, Order_Date, Customer_ID, Product_Name
) s
ON t.Order_ID = s.Order_ID
AND t.Order_Date = s.Order_Date
AND t.Customer_ID = s.Customer_ID
AND t.Product_Name = s.Product_Name
WHERE t.Sales_Rep IS NULL OR LTRIM(RTRIM(t.Sales_Rep)) = '';

SELECT DISTINCT
    Channel
FROM ['Orders (Raw)$']
ORDER BY Channel;


-- Standardize Channel values to 'Online' for any entries that are currently 'ONLINE' (case-insensitive, and also trimming any leading/trailing whitespace)
UPDATE ['Orders (Raw)$']
SET Channel = 'Online'
WHERE UPPER(LTRIM(RTRIM(Channel))) = 'ONLINE';

-- Data quality check for Product_Name column: Identify any entries that are NULL, blank, or contain only whitespace, which may indicate missing or incomplete data
SELECT DISTINCT
    Product_Name
FROM ['Orders (Raw)$']
ORDER BY Product_Name;

SELECT Category
FROM ['Orders (Raw)$']
WHERE Category = '???';

SELECT DISTINCT
    Product_Name,
    Category
FROM ['Orders (Raw)$']
ORDER BY Product_Name, Category;

-- Backfill Category values for rows where Category is '???' by looking for other entries with the same Product_Name.
SET t.Category = s.Category
FROM ['Orders (Raw)$'] t
INNER JOIN (
    SELECT Product_Name, MAX(Category) AS Category
    FROM ['Orders (Raw)$']
    WHERE Category IS NOT NULL AND Category <> '???'
    GROUP BY Product_Name
) s
ON t.Product_Name = s.Product_Name
WHERE t.Category = '???';


-- Standardize Category values to have consistent capitalization (e.g., 'Electronics' instead of 'electronics' or 'ELECTRONICS'), while also trimming any leading/trailing whitespace. 
UPDATE ['Orders (Raw)$']
SET Category = CONCAT(
    UPPER(LEFT(LTRIM(RTRIM(Category)), 1)),
    LOWER(SUBSTRING(LTRIM(RTRIM(Category)), 2, LEN(Category)))
)
WHERE Category IS NOT NULL AND Category <> '';

SELECT DISTINCT
    Product_Name,
    Customer_Segment,
    Quantity
FROM ['Orders (Raw)$']
WHERE Quantity = '2551'



-- Identify potential outliers in the Quantity column by calculating the 99th percentile and flagging any records that exceed this threshold. This can help to identify data entry errors or unusually large orders that may require further investigation.

WITH clean_quantities AS (
    SELECT TRY_CAST(Quantity AS FLOAT) AS qty
    FROM   ['Orders (Raw)$']
    WHERE  TRY_CAST(Quantity AS FLOAT) > 0
),
percentile_calc AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.99)
            WITHIN GROUP (ORDER BY qty)
            OVER () AS p99
    FROM clean_quantities
)
SELECT
    o.Order_ID,
    o.Product_Name,
    o.Category,
    o.Customer_Segment,
    o.Channel,
    TRY_CAST(o.Quantity   AS INT)   AS quantity,
    TRY_CAST(o.Unit_Price AS FLOAT) AS unit_price,
    TRY_CAST(o.Line_Total AS FLOAT) AS line_total,

    ROUND(
        TRY_CAST(o.Unit_Price AS FLOAT) * TRY_CAST(o.Quantity AS INT),
    2)                              AS expected_line_total,

    CASE
        WHEN TRY_CAST(o.Quantity AS INT) > p.p99
            THEN 'above_99th_pct'
        ELSE 'within_normal_range'
    END                             AS quantity_flag,

    ROUND(p.p99, 0)                 AS p99_threshold

FROM        ['Orders (Raw)$']  o
CROSS JOIN  percentile_calc    p
WHERE  TRY_CAST(o.Quantity AS FLOAT) > 0
ORDER BY quantity DESC;

UPDATE ['Orders (Raw)$']
SET QUANTITY = TRY_CAST(QUANTITY AS INT)
WHERE TRY_CAST(QUANTITY AS FLOAT) > 0;

SELECT *
FROM ['Orders (Raw)$']


UPDATE ['Orders (Raw)$']
SET [Discount_%] = 0
WHERE TRY_CAST([Discount_%] AS FLOAT) IS NULL

ALTER TABLE ['Orders (Raw)$']
ADD expected_line_total FLOAT NULL;

UPDATE ['Orders (Raw)$']
SET expected_line_total = ROUND(Quantity * Unit_Price * (1 - [Discount_%] / 100), 2);

SELECT 
    Quantity,
    Unit_Price,
    [Discount_%],
    line_total,
    expected_line_total
FROM ['Orders (Raw)$']
WHERE expected_line_total <> line_total;

ALTER TABLE ['Orders (Raw)$']
DROP COLUMN expected_quantity;

ALTER TABLE ['Orders (Raw)$']
ADD expected_discount INT NULL;


UPDATE ['Orders (Raw)$']
SET expected_quantity = TRY_CAST(ROUND(Line_Total / (Unit_Price * (1 - [Discount_%] / 100)), 0) AS INT)
WHERE TRY_CAST(Line_Total AS FLOAT) > 0
  AND TRY_CAST(Unit_Price AS FLOAT) > 0;

UPDATE ['Orders (Raw)$']
SET expected_discount = TRY_CAST(ROUND(((expected_line_total - line_total) / (expected_line_total)) * 100, 0) AS INT)
WHERE TRY_CAST(Line_Total AS FLOAT) > 0
  AND TRY_CAST(Unit_Price AS FLOAT) > 0
  AND TRY_CAST(Quantity AS FLOAT) > 0;

SELECT 
    Quantity,
    Unit_Price,
    line_total,
    expected_line_total,
    [Discount_%],
    expected_discount
FROM ['Orders (Raw)$']
WHERE expected_discount LIKE '%-%'
   OR expected_discount >= 80;

-- Convert negative values in Quantity and expected_line_total columns to positive
UPDATE ['Orders (Raw)$']
SET Quantity = ABS(Quantity)
WHERE Quantity < 0;

UPDATE ['Orders (Raw)$']
SET expected_line_total = ABS(expected_line_total)
WHERE expected_line_total < 0;

UPDATE ['Orders (Raw)$']
SET [expected_discount] = ROUND(
    100 * (1 - (line_total / NULLIF(Quantity * Unit_Price, 0))), 2
)
WHERE 
    (TRY_CAST([expected_discount] AS FLOAT) = 0 OR [expected_discount] IS NULL)
    AND Quantity > 0
    AND Unit_Price > 0
    AND line_total < (Quantity * Unit_Price);

UPDATE ['Orders (Raw)$']
SET Line_Total = ABS(Line_Total)
WHERE Line_Total < 0;

SELECT 
    Quantity,
    Unit_Price,
    line_total,
    expected_line_total,
    [Discount_%],
    expected_discount
FROM ['Orders (Raw)$']
WHERE expected_discount NOT LIKE '%-%'
  AND expected_discount < 80
  AND [Discount_%] <> expected_discount;

BEGIN TRANSACTION

UPDATE ['Orders (Raw)$']
SET [Discount_%] = expected_discount
WHERE expected_discount NOT LIKE '%-%'
  AND expected_discount < 80
  AND [Discount_%] <> expected_discount
  AND (TRY_CAST([Discount_%] AS FLOAT) = 0 OR [Discount_%] IS NULL);
COMMIT TRANSACTION;

BEGIN TRANSACTION
UPDATE ['Orders (Raw)$']
SET Quantity =
    TRY_CAST(
        ROUND(
            Line_Total /
            (Unit_Price * (1 - [Discount_%] / 100.0)),
            0
        ) AS INT
    )
FROM ['Orders (Raw)$']
WHERE expected_discount LIKE '%-%'
   OR expected_discount >= 80;
COMMIT TRANSACTION;

SELECT 
    Quantity,
    Unit_Price,
    line_total,
    expected_line_total,
    [Discount_%],
    expected_discount
FROM ['Orders (Raw)$']
WHERE Quantity = 0