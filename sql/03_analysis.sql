-- ============================================================
-- Q1. Market overview: size and median price by room type
-- ============================================================
SELECT
    room_type,
    count(*)                                                   AS listings,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY price))  AS median_price,
    round(avg(review_scores_rating)::numeric, 2)               AS avg_rating
FROM listings
GROUP BY room_type
ORDER BY listings DESC;

-- ============================================================
-- Q2. Neighbourhood pricing (entire homes, n >= 30)
-- ============================================================
SELECT
    neighbourhood_cleansed                                      AS neighbourhood,
    count(*)                                                    AS listings,
    round(percentile_cont(0.25) WITHIN GROUP (ORDER BY price))  AS p25_price,
    round(percentile_cont(0.50) WITHIN GROUP (ORDER BY price))  AS median_price,
    round(percentile_cont(0.75) WITHIN GROUP (ORDER BY price))  AS p75_price
FROM listings
WHERE room_type = 'Entire home/apt'
GROUP BY neighbourhood_cleansed
HAVING count(*) >= 30
ORDER BY median_price DESC;

-- ============================================================
-- Q3. Revenue potential by neighbourhood
-- Occupancy model (Inside Airbnb "San Francisco model"):
--   * ~50% of guests leave a review  -> bookings = reviews / 0.5
--   * average stay in Rome assumed 3.5 nights
--   * occupancy capped at 70%
-- est_nights_month = LEAST(reviews_per_month / 0.5 * 3.5, 0.7 * 30.42)
-- ============================================================
WITH revenue AS (
    SELECT
        neighbourhood_cleansed AS neighbourhood,
        price,
        price * LEAST(coalesce(reviews_per_month, 0) / 0.5 * 3.5,
                      0.7 * 30.42)                AS est_monthly_revenue
    FROM listings
    WHERE room_type = 'Entire home/apt'
      AND number_of_reviews >= 5          -- enough signal for the model
)
SELECT
    neighbourhood,
    count(*)                                                                  AS listings,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY est_monthly_revenue))   AS median_est_monthly_rev,
    rank() OVER (ORDER BY percentile_cont(0.5)
                 WITHIN GROUP (ORDER BY est_monthly_revenue) DESC)            AS revenue_rank
FROM revenue
GROUP BY neighbourhood
HAVING count(*) >= 30
ORDER BY revenue_rank;

-- ============================================================
-- Q4. Seasonality: forward prices and blocked share by month
-- (calendar = host expectations for the NEXT 12 months)
-- ============================================================
SELECT
    month,
    round(avg(avg_price))                                            AS avg_nightly_price,
    round(100.0 * sum(days_blocked) / sum(days_total), 1)            AS pct_days_blocked
FROM calendar_monthly
GROUP BY month
ORDER BY month;

-- ============================================================
-- Q5. Capacity sweet spot: revenue per guest by group size
-- ============================================================
WITH rev AS (
    SELECT
        CASE
            WHEN accommodates <= 2 THEN '1-2'
            WHEN accommodates <= 4 THEN '3-4'
            WHEN accommodates <= 6 THEN '5-6'
            ELSE '7+'
        END AS capacity_band,
        accommodates,
        price * LEAST(coalesce(reviews_per_month, 0) / 0.5 * 3.5,
                      0.7 * 30.42) AS est_monthly_revenue
    FROM listings
    WHERE room_type = 'Entire home/apt' AND number_of_reviews >= 5
)
SELECT
    capacity_band,
    count(*)                                                                AS listings,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY est_monthly_revenue)) AS median_est_monthly_rev,
    round(percentile_cont(0.5) WITHIN GROUP
          (ORDER BY est_monthly_revenue / accommodates))                    AS median_rev_per_guest
FROM rev
GROUP BY capacity_band
ORDER BY capacity_band;

-- ============================================================
-- Q6. Market structure: professional hosts
-- ============================================================
SELECT
    CASE
        WHEN calculated_host_listings_count = 1  THEN '1 listing'
        WHEN calculated_host_listings_count <= 5 THEN '2-5'
        WHEN calculated_host_listings_count <= 20 THEN '6-20'
        ELSE '21+'
    END AS host_size,
    count(*)                                          AS listings,
    round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_of_market
FROM listings
GROUP BY 1
ORDER BY min(calculated_host_listings_count);

-- ============================================================
-- Q7. Regulation: share of listings showing a license / CIN
-- ============================================================
SELECT
    neighbourhood_cleansed                              AS neighbourhood,
    count(*)                                            AS listings,
    round(100.0 * avg(has_license::int), 1)             AS pct_with_license
FROM listings
GROUP BY neighbourhood_cleansed
HAVING count(*) >= 30
ORDER BY pct_with_license DESC;
