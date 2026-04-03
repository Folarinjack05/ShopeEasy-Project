
-- -----CREATING THE DATABASE-----
CREATE DATABASE Marketing_Project;


-- ----ASSESSING THE DATA--------
SELECT * 
FROM cleaned_dbo_customer_journey;

SELECT * 
FROM cleaned_dbo_customer_reviews;

SELECT * 
FROM cleaned_dbo_customers;

SELECT * 
FROM cleaned_dbo_engagement_data;

SELECT * 
FROM cleaned_dbo_geography;

SELECT * 
FROM cleaned_dbo_products;



-- ---------------------CUSTOMER FUNNEL AND JOURNEY ANALYSIS----------------------------------
----------------------------------------------------------------------------------------------

-- -----UNDERSTANDING THE FUNNEL STRUCTURE-----
SELECT DISTINCT STAGE -- Select unique funnel stages from the customer journey
FROM cleaned_dbo_customer_journey
ORDER BY Stage; -- 

-- ------ASSESSING JOURNEY VOLUME PER STAGE/DROP-OFF SIGNALS -----
SELECT STAGE, -- Represents different steps in the customer journey(e.g Homepage, ProductPage and Checkout)
    COUNT(DISTINCT CustomerID) AS unique_customers -- Counts how many unique customers appear at each funnel stage
FROM cleaned_dbo_customer_journey
GROUP BY Stage -- Group results by stage to aggregate customer counts for each step in the funnel
ORDER BY unique_customers DESC; -- Sorts stages from the highest customer traffic to lowest


-- -----ANALYZING STAGE-TO-TAGE DROP-OFF RATE USING WINDOW FUNCTIONS-------
WITH stage_counts AS (  -- CTE: Count the number of unique customers that reached each stage of the funnel.
    SELECT 
    stage, -- Funnel stage (e.g., Checkout, ProductPage, Homepage)
    COUNT(DISTINCT CustomerID) AS customers -- Counts the number of unique customers who reached this stage
    FROM cleaned_dbo_customer_journey
    GROUP BY stage -- Group by stage to calculate the total number of customers
    )
SELECT -- Final Query: Calculate stage-to-stage conversion rates
stage, -- Current stage in the customer funnel
customers, -- Total number of customers who reached this stage
LAG(customers) OVER (ORDER BY customers DESC) 
     AS previous_stage_customers, -- LAG retrieves the customer count from the previous stage
ROUND( -- Conversion rate from previous stage to current stage
	(customers * 1.0/ LAG(customers) OVER (ORDER BY customers DESC)) * 100, 2) 
    AS stage_conversion_rate
FROM stage_counts;


-- -----TIME SPENT PER FUNNEL STAGE(IDENTIFYING FRICTION AND CONFUSION AT SPECIFIC STAGES)-------
SELECT stage, 
    ROUND(AVG(duration),2) AS Average_Time_Spent -- Calculate average duration customers spend at each stage
FROM cleaned_dbo_customer_journey
GROUP BY stage  -- Group durations by stage
ORDER BY Average_Time_Spent; -- Highlight stages with longest time spent


-- -----IDENTIFYING EXIT STAGES(WHERE USERS ARE LEAVING)-------
WITH last_stage AS ( -- CTE: Identify the final stage reached by each customer
    SELECT 
    CustomerID,  -- Unique identifier for each customer
    MAX(Stage) AS final_stage -- MAX is used assuming stages follow a sequential funnel order
    FROM cleaned_dbo_customer_journey
    GROUP BY CustomerID -- Group by customer so each row represents the final stage reached
    )
SELECT -- Final Query: Count how many customers exit at each final stage
final_stage,  -- The last stage customers reached before leaving the funnel
COUNT(CustomerID) AS customers_exited -- Number of customers whose journey ended at this stage
FROM last_stage
GROUP BY final_stage -- Group by final stage to aggregate customer exits
ORDER BY customers_exited DESC; -- Sort results from the most common exit stage to the least common


-- -----JOURNEY DURATION(CONVERTERS VS NON-CONVERTERS)-------
WITH journey_summary AS (  -- CTE: Summarizes journey behavior for each individual customer
    SELECT 
    CustomerID, -- Unique identifier for each customer
    SUM(Duration) AS total_duration, -- Total time spent across all stages of the customer's journey
    MAX(CASE 
            WHEN stage= 'purchase' THEN 1 
            ELSE 0 
            END) AS converted  -- Conversion indicator: Flag customers who reached the purchase stage
    FROM cleaned_dbo_customer_journey
    GROUP BY CustomerID -- Groups by customer so each row represents the summarized journey
    ) 
SELECT -- Final Query: Compare average journey time by conversion status
converted, -- 1 = Converted, 0 = Not Converted
ROUND(AVG(total_duration),2) AS avg_journey_time  -- Average total journey duration for each group
FROM journey_summary
GROUP BY converted; -- Groups by conversion status


-- -----COMMON CUSTOMER JOURNEY PATHS-------
SELECT CustomerID, -- Unique identifier for each customer
    GROUP_CONCAT(stage ORDER BY VisitDate 
    SEPARATOR ' → ') AS journey_path -- GROUP_CONCAT combines multiple journey stages into a single string
									 -- ORDER BY VisitDate ensures the stages appear in chronological order
									 -- SEPARATOR ' → ' visually represents the flow of the customer journey
FROM cleaned_dbo_customer_journey
GROUP BY CustomerID; -- Group results by customer so each row represents



-- ---------------------CAMPAIGN AND ENGAGEMENT PERFORMANCE ANALYSIS-------------------------
---------------------------------------------------------------------------------------------

-- --------CAMPAIGN REACH AND ENGAGEMENT VOLUME------------
SELECT CampaignID, 
    COUNT(DISTINCT ContentID) AS total_content, -- Aggregates engagement metrics at campaign level
	SUM(Views) AS total_views, -- Total number of views generated 
    SUM(Clicks) AS total_clicks, -- Total number of clicks received
	SUM(Likes) AS total_Likes -- Total number of likes or positive reactions
FROM cleaned_dbo_engagement_data
GROUP BY CampaignID  -- Group engagement metrics by campaign
ORDER BY total_views DESC; -- Shows most visible campaigns first


-- ----------ENGAGEMENT RATE PER CAMPAIGN----------------
SELECT CampaignID, -- Calculates engagement efficiency per campaign
	SUM(Views) AS total_views, -- Total number of times campaign-related content was viewed
    SUM(Clicks) AS total_clicks,  -- Total number of clicks generated by the campaign
    ROUND((SUM(Clicks)*1.0 / NULLIF(SUM(Views), 0)) * 100, 2) AS click_through_rate -- Engagement rate = clicks divided by views
FROM cleaned_dbo_engagement_data
GROUP BY CampaignID -- Group results by campaign to calculate engagement metrics
ORDER BY click_through_rate DESC;   -- Ranks campaigns by engagement quality


-- --------CONTENT TYPE PERFORMANCE------------
SELECT ContentType, COUNT(ContentID) AS content_count, -- Analyzes engagement performance by content type
     SUM(Views) AS total_views,  -- Total number of views generated 
     SUM(Clicks) AS total_clicks, -- Total number of clicks received
     SUM(Likes) AS total_Likes, -- Total number of likes or positive reactions
     ROUND((SUM(Clicks)*1.0 / NULLIF(SUM(Views), 0)) * 100, 2) AS engagement_rate -- This metric measures engagement efficiency
FROM cleaned_dbo_engagement_data
GROUP BY ContentType -- Group results by content type
ORDER BY engagement_rate DESC; -- Sort results from highest engagement rate to lowest


-- --------CAMPAIGN PERFORMANCE BY PRODUCT------------
SELECT p.ProductName, e.CampaignID, -- -- Join engagement data with product information
	SUM(Views) AS total_views, -- Total number of times the product content was viewed
    SUM(Clicks) AS total_clicks, -- Total number of user clicks generated for the product within the campaign
    ROUND((SUM(e.Clicks)*1.0 / NULLIF(SUM(e.Views),
    0)) * 100, 2) AS click_through_rate -- Click-through efficiency per product-campaign pair
FROM cleaned_dbo_engagement_data e
JOIN cleaned_dbo_products p -- Join engagement data with the product table
    ON e.ProductID = p.ProductID
GROUP BY p.ProductName, e.CampaignID -- Group results by product and campaign
ORDER BY click_through_rate DESC;   -- Sort results from highest CTR to lowest


-- --------ENGAGEMENT TRENDS OVER TIME------------
SELECT EngagementDate, SUM(Views) AS daily_views, SUM(Clicks) AS daily_clicks, -- Analyze daily engagement trends
    SUM(Likes) AS dailys_likes
FROM cleaned_dbo_engagement_data
GROUP BY EngagementDate -- Group data by date to aggregate engagement metrics
ORDER BY EngagementDate; -- Sort results chronologically to visualize trends over time


-- --------HIGH ENGAGEMENT CONTENT IDENTIFICATION------------
SELECT ContentID, ContentType, CampaignID, -- Identify individual content items with strong engagement
    Views, Clicks, Likes, 
    (Clicks + Likes) AS engagement_score  -- Engagement score combining multiple signals
FROM cleaned_dbo_engagement_data
ORDER BY engagement_score DESC -- Sort content by engagement score from highest to lowest
LIMIT 10; -- Limit results to the top 10 highest-performing content items


-- ------------CAMPAIGN → FUNNEL BRIDGE---------------
SELECT e.CampaignID, 
    COUNT(DISTINCT j.CustomerID) AS customers_reached -- Counts the number of unique customers associated with each campaign
FROM cleaned_dbo_engagement_data e
JOIN cleaned_dbo_customer_journey j -- Join engagement data with the customer journey dataset
ON e.ProductID = j.ProductID
GROUP BY e.CampaignID -- Group results by campaign to calculate the number of customers reached
ORDER BY customers_reached DESC; -- Sort campaigns from highest reach to lowest


-- ---------------------CAMPAIGN → FUNNEL/CONVERSION IMPACT ANALYSIS-------------------------
---------------------------------------------------------------------------------------------

-- --------IDENTIFY CAMPAIGN-EXPOSED CUSTOMERS------------
SELECT DISTINCT -- Identifies customers who interacted with products linked to campaigns
j.CustomerID, -- Unique identifier for each customer
e.CampaignID -- Unique identifier for the marketing campaign
FROM cleaned_dbo_customer_journey j
JOIN cleaned_dbo_engagement_data e -- Join the customer journey dataset with the engagement dataset
ON  j.ProductID = e.ProductID ;


-- ------------FUNNEL PROGRESSION BY CAMPAIGN---------------
WITH campaign_journey AS ( -- Measure deepest funnel stage reached by customers per campaign
    SELECT
        e.CampaignID, -- Campaign identifier
        j.CustomerID, -- Customer identifier
        MAX(j.stage) AS Max_Stage -- Determines the deepest funnel stage reached by the customer
	FROM cleaned_dbo_engagement_data e  -- Join engagement data with the customer journey table
    JOIN cleaned_dbo_customer_journey j
        ON j.ProductID = e.ProductID
    GROUP BY e.CampaignID, j.CustomerID  -- Group by campaign and customer so that each row represents
    )
SELECT -- Final Query: Count how many customers reached each funnel stage
    CampaignID, -- Campaign identifier
    Max_Stage,  -- Deepest funnel stage reached
    COUNT(CustomerID) AS customers_reached  -- Count how many customers reached each stage per campaign
FROM campaign_journey
GROUP BY CampaignID, Max_Stage -- This aggregates how many customers reached each stage
ORDER BY CampaignID, customers_reached; -- Sort results by campaign first, then by number of customers


-- ------------CONVERSION RATE BY CAMPAIGN--------------- 
WITH campaign_conversion AS ( -- CTE: Determine whether each customer exposed to a campaign
    SELECT
        e.CampaignID, -- Campaign identifier
        j.CustomerID, -- Customer identifier
        MAX(
            CASE
                WHEN j.stage='Purchase' THEN 1
                ELSE 0
			END -- If any stage in the journey equals "Purchase", the product is marked as converted (1)
		) AS converted
    FROM cleaned_dbo_engagement_data e -- Join engagement data with customer journey data
    JOIN cleaned_dbo_customer_journey j
        ON e.ProductID = j.ProductID
    GROUP BY e.CampaignID, j.CustomerID  -- Group by campaign and customer to evaluate conversion
    )
SELECT CampaignID, -- Final Query: Calculate conversion metrics for each campaign
    COUNT(CustomerID) AS total_customers, -- Total number of customers who interacted with the campaign
    SUM(converted) AS converted_customers, -- Total number of customers who completed a purchase
    ROUND((SUM(converted)*1.0/ COUNT(CustomerID))*100, -- Conversion rate calculation
    2) AS conversion_rate
FROM campaign_conversion
GROUP BY CampaignID -- Group results by campaign to calculate campaign-level performance
ORDER BY conversion_rate DESC; -- Sort campaigns from highest conversion rate to lowest


-- ------------TIME-TO-CONVERSION CAMPAIGN--------------- 
WITH campaign_time AS (  -- CTE: Calculate the total customer journey time for each campaign
    SELECT
        e.CampaignID, -- Campaign identifier
        j.CustomerID, -- Customer identifier
        SUM(j.Duration) AS total_journey_time,  -- Total time spent by the customer throughout the journey
        MAX(
            CASE
                WHEN j.stage ='Purchase' THEN 1
                ELSE 0
			END -- If any stage in the journey equals "Purchase", the product is marked as converted (1)
		) AS converted
    FROM cleaned_dbo_engagement_data e -- Join engagement data with customer journey data
    JOIN cleaned_dbo_customer_journey j
        ON e.ProductID = j.ProductID
    GROUP BY e.CampaignID, j.CustomerID  -- Group results by campaign and customer
    ) 
SELECT CampaignID, -- Final Query: Calculate average journey time for customers who converted
     ROUND((AVG(total_journey_time)),2) AS avg_time_to_conversion
FROM campaign_time
WHERE converted = 1 -- Only includes customers who actually converted
GROUP BY CampaignID -- Group by campaign to compute the average conversion time for each campaign
ORDER BY avg_time_to_conversion; -- Sort campaigns by the fastest conversion time


-- ------------ENGAGEMENT QUALITY VS CONVERSION--------------- 
WITH engagement_summary AS (  -- CTE 1: Aggregate engagement metrics for each campaign and product
    SELECT
        CampaignID, -- Campaign identifier
        ProductID, -- Product identifier
        SUM(Views) AS Total_Views, -- Total number of views
        SUM(Clicks) AS Total_Clicks, -- Total number of clicks
        SUM(Likes) AS Total_Likes -- Total number of clicks
		FROM cleaned_dbo_engagement_data 
        GROUP BY CampaignID, ProductID  -- Group by campaign and product to aggregate engagement metrics
        ),  
        conversion_summary AS( -- CTE 2: Identifies whether a product was eventually purchased
        SELECT ProductID,
        MAX(
            CASE
                WHEN Stage ='Purchase' THEN 1
                ELSE 0
			END -- If any stage in the journey equals "Purchase", the product is marked as converted (1)
		) AS Converted
    FROM cleaned_dbo_customer_journey 
    GROUP BY ProductID -- Group by product to evaluate whether that product had a purchase event
    )
SELECT e.CampaignID, e.Total_Views, e.Total_Clicks, e.Total_Likes, c.converted
FROM engagement_summary e
JOIN conversion_summary c -- Join engagement metrics with conversion outcomes using ProductID
    ON e.ProductID = c.ProductID -- This links marketing interactions with customer purchase behavior
ORDER BY e.total_clicks DESC; -- Sorts campaigns by highest click engagement



-- ----------------------------PRODUCT AND REVENUE PERFORMANCE-------------------------------
---------------------------------------------------------------------------------------------

-- ------------PRODUCT SALES VOLUME--------------- 
SELECT p.ProductName, -- Product name from the products table
    COUNT(j.JourneyID) AS Purchase_Count  -- Counts the number of purchase records for each product
FROM cleaned_dbo_customer_journey j
JOIN cleaned_dbo_products p -- Join the customer journey table with the products table
    ON j.ProductID = p.ProductID -- This connects purchase actions with product information
WHERE j.Action = 'Purchase' -- Filters the dataset to include only rows where a purchase occurred
GROUP BY p.ProductName -- Groups results by product name
ORDER BY Purchase_Count DESC; -- Sort the results from highest purchase count to lowest


-- ------------PRODUCT REVENUE CONTRIBUTION--------------- 
SELECT  p.ProductName,  -- Name of the product from the products table
    COUNT(j.JourneyID) AS Units_Sold,  -- Counts the number of purchase records associated with the product
    p.Price, -- Unit price of the product
    COUNT(j.JourneyID) * p.Price AS Total_Revenue -- Calculates the total revenue i.e Units Sold × Product Price
FROM cleaned_dbo_customer_journey j 
JOIN cleaned_dbo_products p -- Join the customer journey table with the products table
    ON j.ProductID = p.ProductID -- This connects purchase events with product information
WHERE j.Action = 'Purchase' -- Filters the dataset to include only completed purchase actions
GROUP BY p.ProductName, p.Price -- Groups results by product name and price
ORDER BY Total_Revenue DESC; -- Sorts products with the highest revenue first


-- ------------ REVENUE BY PRODUCT CATEGORY--------------- 
SELECT  p.Category, -- Aggregates revenue by product category
    COUNT(j.JourneyID) AS Units_Sold, -- Counts the number of purchase records in the customer journey table
    SUM(p.Price) AS Total_Revenue  -- Calculates total revenue generated from purchases
FROM cleaned_dbo_customer_journey j
JOIN cleaned_dbo_products p -- Join the customer journey table with the products table
    ON j.ProductID = p.ProductID -- This allows us to connect purchase events with product attributes
WHERE j.Action = 'Purchase' -- Filter the dataset to include only completed purchases
GROUP BY p.Category -- Group results by product category
ORDER BY Total_Revenue DESC; -- Sorts the top-performing categories in terms of sales revenue


-- ------------CAMPAIGN DRIVEN REVENUE--------------- 
SELECT e.CampaignID, -- Calculate revenue influenced by campaigns
    SUM(p.Price) AS Campaign_Revenue -- sum the product prices for all purchases attributed to that campaign
FROM cleaned_dbo_engagement_data e
JOIN cleaned_dbo_customer_journey j -- Joins engagement data with the customer journey table
    ON e.ProductID = j.ProductID
JOIN cleaned_dbo_products p -- Joins the products table to obtain product pricing information
    ON j.ProductID = p.ProductID
WHERE j.Action = 'Purchase'-- Filters the dataset to include only completed purchase actions
GROUP BY e.CampaignID -- Group results by campaign to calculate total revenue for each campaign
ORDER BY Campaign_Revenue DESC; -- Sorts campaigns from highest revenue to lowest



-- ------------CONVERSION EFFICIENCY PER PRODUCT--------------- 
WITH product_views AS ( -- Calculate average journey time per campaign for converted customers
    SELECT
        ProductID, -- Unique identifier for each product
        SUM(Views) AS Views
    FROM cleaned_dbo_engagement_data 
    GROUP BY ProductID -- Groups results so each product has one total view count
    ),
    product_purchase AS (
    SELECT
        ProductID, -- Product identifier
        COUNT(*) AS purchase
	FROM cleaned_dbo_customer_journey
	WHERE Action = 'Purchase' -- Only considers rows where a purchase actually occurred
	GROUP BY ProductID -- Aggregate purchase counts per product
    )
SELECT ProductName, -- Name of the product from the product table
    v.Views, -- Total number of product views
    pr.purchase, -- Total number of purchases
    ROUND((pr.purchase * 1.0 / NULLIF (v.Views,0)) *100, 2 )AS conversion_rate -- Conversion rate expressed as a percentage
FROM cleaned_dbo_products p
JOIN product_views v ON p.ProductID = v.ProductID -- Join the views CTE to the product table to attach view data
JOIN product_purchase pr ON p.ProductID = pr.ProductID -- Join the purchases CTE to attach purchase data
ORDER BY conversion_rate DESC; -- Sort products from highest conversion rate to lowest


-- ------------Price Tier Categorization--------------- 
SELECT ProductID, productName, Price,
    CASE
        WHEN Price < 50 THEN 'Low Price'
        WHEN Price BETWEEN 50 AND 150 THEN 'Mid Price'
        ELSE 'Premium'
    END AS Price_Tier
FROM Cleaned_dbo_products;




















