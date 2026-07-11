"""
Generates synthetic Indian transaction dataset for training Core ML models.
Run this first before train_classifier.py or train_anomaly.py.
"""

import pandas as pd
import numpy as np
import random

random.seed(42)
np.random.seed(42)

MERCHANTS = {
    "food": [
        "Swiggy", "Zomato", "McDonald's", "Dominos", "KFC", "Burger King",
        "Blinkit", "Dunzo", "Swiggy Instamart", "BigBasket", "Tea Stall",
        "Chai Point", "Subway", "Pizza Hut", "Haldirams"
    ],
    "transport": [
        "Ola", "Uber", "Rapido", "Auto Rickshaw", "BMTC", "Namma Metro",
        "Indian Railways", "RedBus", "IndiGo", "Air India", "Ola Electric"
    ],
    "bills": [
        "Jio", "Airtel", "BSNL", "Electricity Bill", "Water Bill",
        "HDFC EMI", "ICICI EMI", "LIC Premium", "Gas Bill", "Society Maintenance",
        "Netflix", "Amazon Prime", "Hotstar", "Spotify", "YouTube Premium"
    ],
    "entertainment": [
        "BookMyShow", "PVR Cinemas", "INOX", "Steam", "PlayStation Store",
        "Myntra", "Ajio", "Nykaa", "Decathlon", "Crossword"
    ],
    "other": [
        "Amazon", "Flipkart", "Apollo Pharmacy", "1mg", "Practo",
        "HDFC Bank ATM", "SBI ATM", "Paytm", "PhonePe", "Google Pay",
        "Zepto", "D-Mart", "Big Bazaar", "Reliance Fresh", "More Supermarket"
    ]
}

AMOUNT_RANGES = {
    "food":          (50,   800),
    "transport":     (20,   500),
    "bills":         (199, 5000),
    "entertainment": (100, 2000),
    "other":         (100, 5000)
}

def merchant_bucket(name: str) -> int:
    """Maps merchant name to a 0-9 numeric bucket for the ML model."""
    buckets = {
        "food": [0, 1], "transport": [2, 3],
        "bills": [4, 5], "entertainment": [6, 7], "other": [8, 9]
    }
    for category, merchant_list in MERCHANTS.items():
        if name in merchant_list:
            idx = merchant_list.index(name) % 2
            return buckets[category][idx]
    return 9

rows = []
for _ in range(5000):
    # 10% noise: assign wrong category to simulate real-world messiness
    category = random.choice(list(MERCHANTS.keys()))
    true_category = category
    if random.random() < 0.10:
        true_category = random.choice(list(MERCHANTS.keys()))

    merchant = random.choice(MERCHANTS[category])
    lo, hi = AMOUNT_RANGES[category]
    amount = round(random.uniform(lo, hi), 2)
    hour = random.randint(0, 23)
    dow = random.randint(0, 6)
    bucket = merchant_bucket(merchant)

    rows.append({
        "amount": amount,
        "hour_of_day": hour,
        "day_of_week": dow,
        "merchant_bucket": bucket,
        "merchant_name": merchant,
        "category": true_category
    })

df = pd.DataFrame(rows)
df.to_csv("data/synthetic_transactions.csv", index=False)
print(f"Generated {len(df)} rows")
print(df["category"].value_counts())
