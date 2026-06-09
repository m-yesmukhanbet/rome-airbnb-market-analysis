-- Typed, clean tables built from staging.

DROP TABLE IF EXISTS calendar;
CREATE TABLE calendar AS
SELECT
    listing_id::bigint                                            AS listing_id,
    date::date                                                    AS day,
    (available = 't')                                             AS available,
    NULLIF(regexp_replace(price, '[$,]', '', 'g'), '')::numeric   AS price
FROM stg_calendar;

CREATE INDEX idx_calendar_listing ON calendar (listing_id);
CREATE INDEX idx_calendar_day     ON calendar (day);

DROP TABLE IF EXISTS reviews_slim;
CREATE TABLE reviews_slim AS
SELECT
    listing_id::bigint AS listing_id,
    date::date         AS review_date
FROM stg_reviews;

CREATE INDEX idx_reviews_listing ON reviews_slim (listing_id);

-- Forward-looking monthly aggregate per listing (host pricing expectations)
DROP TABLE IF EXISTS calendar_monthly;
CREATE TABLE calendar_monthly AS
SELECT
    listing_id,
    date_trunc('month', day)::date                      AS month,
    avg(price)                                          AS avg_price,
    count(*)                                            AS days_total,
    count(*) FILTER (WHERE NOT available)               AS days_blocked
FROM calendar
GROUP BY listing_id, date_trunc('month', day);

-- Staging can be dropped to free space (optional):
-- DROP TABLE stg_calendar; DROP TABLE stg_reviews;
