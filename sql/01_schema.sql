DROP TABLE IF EXISTS stg_calendar;
CREATE TABLE stg_calendar (
    listing_id      TEXT,
    date            TEXT,
    available       TEXT,
    price           TEXT,
    adjusted_price  TEXT,
    minimum_nights  TEXT,
    maximum_nights  TEXT
);

DROP TABLE IF EXISTS stg_reviews;
CREATE TABLE stg_reviews (
    listing_id    TEXT,
    id            TEXT,
    date          TEXT,
    reviewer_id   TEXT,
    reviewer_name TEXT,
    comments      TEXT
);
