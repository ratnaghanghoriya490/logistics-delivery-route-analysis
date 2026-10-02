
-- =========================
-- TASK 1: DATA CLEANING
-- =========================

-- 1. Find duplicate Order_ID
SELECT Order_ID, COUNT(*) AS count
FROM orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- Result: No duplicate records found

-- 2. Replace NULL Traffic_Delay_Min with route average

SET SQL_SAFE_UPDATES = 0;

UPDATE routes r1
JOIN (
    SELECT Route_ID, AVG(Traffic_Delay_Min) AS avg_delay
    FROM routes
    GROUP BY Route_ID
) r2
ON r1.Route_ID = r2.Route_ID
SET r1.Traffic_Delay_Min = r2.avg_delay
WHERE r1.Traffic_Delay_Min IS NULL;

-- Result: No NULL values found

-- 3. Convert date columns into YYYY-MM-DD format

UPDATE orders
SET 
    Order_Date = STR_TO_DATE(Order_Date, '%Y-%m-%d'),
    Expected_Delivery_Date = STR_TO_DATE(Expected_Delivery_Date, '%Y-%m-%d'),
    Actual_Delivery_Date = STR_TO_DATE(Actual_Delivery_Date, '%Y-%m-%d');


-- Note: Dates are already in correct format (YYYY-MM-DD), no conversion required

-- Add flag column for invalid data

SELECT 
    Order_ID,
    Order_Date,
    Actual_Delivery_Date,
    CASE 
        WHEN Actual_Delivery_Date < Order_Date THEN 'Invalid'
        ELSE 'Valid'
    END AS Status
FROM orders;

-- =========================
-- TASK 2: DELIVERY DELAY ANALYSIS
-- =========================
-- 1. Calculate delivery delay for each order (in days)

SELECT 
    Order_ID,
    Order_Date,
    Actual_Delivery_Date,
    DATEDIFF(Actual_Delivery_Date, Order_Date) AS Delivery_Delay_Days
FROM orders;

-- 2. Top 10 delayed routes based on average delay
use logistics_project;
SELECT 
    Route_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Delay_Days
FROM orders
GROUP BY Route_ID
ORDER BY Avg_Delay_Days DESC
LIMIT 10;
-- 3. Rank all orders by delay within each warehouse

SELECT 
    Warehouse_ID,
    Order_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days,
    
    RANK() OVER (
        PARTITION BY Warehouse_ID 
        ORDER BY DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) DESC
    ) AS Rank_in_Warehouse

FROM orders;

-- =========================
-- TASK 3: ROUTE OPTIMIZATION
-- =========================
-- Average delivery time for each route

SELECT 
    Route_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Delivery_Time_Days
FROM orders
GROUP BY Route_ID;
-- Average traffic delay for each route
USE logistics_project;
SELECT
    Route_ID,
    AVG(Traffic_Delay_Min) AS Avg_Traffic_Delay_Min
FROM routes
GROUP BY Route_ID;

-- Efficiency ratio (Distance / Time)

SELECT 
    Route_ID,
    (Distance_KM / Average_Travel_Time_Min) AS Efficiency_Ratio
FROM routes;
-- Find 3 routes with worst efficiency ratio

SELECT 
    Route_ID,
    (Distance_KM / Average_Travel_Time_Min) AS Efficiency_Ratio
FROM routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;
-- Find routes with more than 20% delayed shipments
SELECT 
    Route_ID,
    COUNT(*) AS Total_Orders,
    SUM(CASE 
        WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 
        ELSE 0 
    END) AS Delayed_Orders,
    (SUM(CASE 
        WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS Delay_Percentage

FROM orders
GROUP BY Route_ID
HAVING Delay_Percentage > 20;
-- Recommend routes for optimization

SELECT 
    Route_ID,
    ROUND(Distance_KM / Average_Travel_Time_Min, 2) AS Efficiency_Ratio,
    Traffic_Delay_Min
FROM routes
WHERE 
    (Distance_KM / Average_Travel_Time_Min) < 0.5
    OR Traffic_Delay_Min > 30;
-- =========================
-- TASK 4  :Warehouse Performance
-- =========================
-- Top 3 warehouses with highest average processing time

SELECT 
    Warehouse_ID,
    AVG(Processing_Time_Min) AS Avg_Processing_Time
FROM warehouses
GROUP BY Warehouse_ID
ORDER BY Avg_Processing_Time DESC
LIMIT 3;
-- Total vs delayed shipments for each warehouse
SELECT
    Warehouse_ID,
    COUNT(*) AS Total_Orders,
    SUM(
        CASE
            WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1
            ELSE 0
        END
    ) AS Delayed_Orders,
    ROUND(
        SUM(
            CASE
                WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Delay_Percentage
FROM orders
GROUP BY Warehouse_ID;
 -- Find bottleneck warehouses using CTE
WITH warehouse_avg AS (
    SELECT
        Warehouse_ID,
        AVG(Processing_Time_Min) AS Avg_Processing_Time
    FROM warehouses
    GROUP BY Warehouse_ID
)
SELECT
    Warehouse_ID,
    Avg_Processing_Time,
    (SELECT AVG(Avg_Processing_Time) FROM warehouse_avg) AS Global_Avg
FROM warehouse_avg
WHERE Avg_Processing_Time >
(
    SELECT AVG(Avg_Processing_Time)
    FROM warehouse_avg
);
-- Rank warehouses based on on-time delivery percentage
SELECT 
    Warehouse_ID,
    (SUM(CASE 
        WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 
        ELSE 0 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage,
    RANK() OVER (
        ORDER BY 
        (SUM(CASE 
            WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 
            ELSE 0 
        END) * 100.0 / COUNT(*)) DESC
    ) AS Warehouse_Rank
FROM orders
GROUP BY Warehouse_ID;


-- =========================
-- TASK 5: Delivery Agent Performance
-- =========================

-- Rank agents (per route) by On-Time Delivery Percentage

SELECT
    Agent_ID,
    Route_ID,
    On_Time_Percentage,

    RANK() OVER (
        PARTITION BY Route_ID
        ORDER BY On_Time_Percentage DESC
    ) AS Agent_Rank

FROM deliveryagents;

-- 2. Find agents with On-Time Percentage less than 80%

SELECT
    Agent_ID,
    Route_ID,
    On_Time_Percentage
FROM deliveryagents
WHERE On_Time_Percentage < 80;


-- 3. Compare Average Speed of Top 5 Agents

SELECT 
    AVG(Avg_Speed_KM_HR) AS Average_Speed
FROM (
    SELECT Avg_Speed_KM_HR
    FROM deliveryagents
    ORDER BY On_Time_Percentage DESC
    LIMIT 5
) AS top_agents;


-- 4. Compare Average Speed of Bottom 5 Agents

SELECT 
    AVG(Avg_Speed_KM_HR) AS Average_Speed
FROM (
    SELECT Avg_Speed_KM_HR
    FROM deliveryagents
    ORDER BY On_Time_Percentage ASC
    LIMIT 5
) AS bottom_agents;
-- =========================================
-- TASK 6: Shipment Tracking Analytics
-- =========================================

-- 1. For each order, list the last checkpoint and time
SELECT
    Order_ID,
    Checkpoint,
    Checkpoint_Time
FROM (
    SELECT
        Order_ID,
        Checkpoint,
        Checkpoint_Time,
        ROW_NUMBER() OVER (
            PARTITION BY Order_ID
            ORDER BY Checkpoint_Time DESC
        ) AS rn
    FROM `shipment tracking table`
) t
WHERE rn = 1;

SHOW TABLES;


-- 2. Identify orders with more than 2 delayed checkpoints

SELECT
    Order_ID,
    COUNT(*) AS Delayed_Checkpoints
FROM `shipment tracking table`
WHERE Delay_Reason <> 'None'
GROUP BY Order_ID
HAVING COUNT(*) > 2;

-- 3. Find the most common delay reasons (excluding None)

SELECT
    Delay_Reason,
    COUNT(*) AS Total_Count
FROM `shipment tracking table`
WHERE Delay_Reason <> 'None'
GROUP BY Delay_Reason
ORDER BY Total_Count DESC;

-- 4.Identify orders with exceptionally high delay (>120 hours) to investigate potential bottlenecks.

SELECT
    Order_ID,
    Expected_Delivery_Date,
    Actual_Delivery_Date,
    TIMESTAMPDIFF(HOUR, Expected_Delivery_Date, Actual_Delivery_Date) AS Delay_Hours
FROM orders
WHERE TIMESTAMPDIFF(HOUR, Expected_Delivery_Date, Actual_Delivery_Date) > 120
ORDER BY Delay_Hours DESC;


-- =========================================
-- TASK 7: Advanced KPI Reporting
-- =========================================

-- 1. Average Delivery Delay per country
SELECT
    Warehouse_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Delivery_Delay_Days
FROM orders
GROUP BY Warehouse_ID
ORDER BY Avg_Delivery_Delay_Days DESC;
-- 2. On-Time Delivery Percentage

SELECT
    (
        SUM(
            CASE
                WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*)
    ) AS On_Time_Delivery_Percentage
FROM orders;
-- 3. Average Traffic Delay per Route

SELECT
    Route_ID,
    AVG(Traffic_Delay_Min) AS Avg_Traffic_Delay
FROM routes
GROUP BY Route_ID
ORDER BY Avg_Traffic_Delay DESC;
 -- 4.  Warehouse Utilization % = (Shipments_Handled / Capacity_per_day) * 100.
SELECT
    Warehouse_ID,
    COUNT(Order_ID) AS Shipments_Handled
FROM orders
GROUP BY Warehouse_ID
ORDER BY Shipments_Handled DESC;