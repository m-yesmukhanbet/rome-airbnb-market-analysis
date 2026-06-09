"""
Clean the raw Inside Airbnb listings file for Rome and load it
into PostgreSQL (table: listings) + save a processed CSV.

Snapshot: 14 September 2025.
Run from project root:  python src/clean_listings.py
"""

import pandas as pd
import numpy as np
from sqlalchemy import create_engine

RAW_PATH = "data/raw/listings.csv"
OUT_CSV = "data/processed/listings_clean.csv"
DB_URL = "postgresql+psycopg2://m.yesmukhanbet:12345@localhost:5432/rome_airbnb"

USE_COLS = [
    "id", "name", "host_id", "host_since", "host_is_superhost",
    "calculated_host_listings_count", "neighbourhood_cleansed",
    "latitude", "longitude", "property_type", "room_type",
    "accommodates", "bedrooms", "beds", "price",
    "minimum_nights", "maximum_nights", "availability_365",
    "number_of_reviews", "number_of_reviews_ltm", "reviews_per_month",
    "last_review", "review_scores_rating", "review_scores_location",
    "estimated_occupancy_l365d", "estimated_revenue_l365d",
    "instant_bookable", "license",
]


def main() -> None:
    df = pd.read_csv(RAW_PATH, usecols=lambda c: c in set(USE_COLS))
    n_raw = len(df)
    print(f"Raw rows: {n_raw:,}")

    # --- price: "$1,234.00" -> 1234.0 ---
    df["price"] = (
        df["price"].astype(str)
        .str.replace(r"[$,]", "", regex=True)
        .replace({"nan": np.nan, "": np.nan})
        .astype(float)
    )
    print(f"Rows with a price: {df['price'].notna().sum():,} "
          f"({df['price'].notna().mean():.0%} of raw)")

    # --- booleans: 't'/'f' -> True/False ---
    for col in ["host_is_superhost", "instant_bookable"]:
        df[col] = df[col].map({"t": True, "f": False})

    # --- dates ---
    for col in ["host_since", "last_review"]:
        df[col] = pd.to_datetime(df[col], errors="coerce")

    # --- drop rows without a usable price ---
    df = df[df["price"].notna() & (df["price"] > 0)].copy()
    print(f"After dropping missing/zero price: {len(df):,}")

    # --- trim price outliers (1st-99th percentile) ---
    lo, hi = df["price"].quantile([0.01, 0.99])
    df = df[df["price"].between(lo, hi)].copy()
    print(f"Price window kept: {lo:.0f}-{hi:.0f} EUR -> {len(df):,} rows")

    # --- flags ---
    df["is_short_term"] = df["minimum_nights"] <= 7
    df["has_license"] = df["license"].notna() & (df["license"].astype(str).str.strip() != "")

    # --- save + load to PostgreSQL ---
    df.to_csv(OUT_CSV, index=False)
    engine = create_engine(DB_URL)
    df.to_sql("listings", engine, if_exists="replace", index=False)
    print(f"Saved {OUT_CSV} and loaded {len(df):,} rows into table 'listings'.")

    # --- quick sanity report ---
    print("\nRows by room_type:")
    print(df["room_type"].value_counts())
    print(f"\nMedian price: {df['price'].median():.0f} EUR")
    print(f"Share with license/CIN: {df['has_license'].mean():.1%}")
    print(f"Share with IA revenue estimate: "
          f"{df['estimated_revenue_l365d'].notna().mean():.1%}")


if __name__ == "__main__":
    main()