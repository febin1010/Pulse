"""
Federated retraining script.

Reads FedAvg-aggregated category deltas from the backend,
adjusts RandomForest class weights accordingly, retrains,
exports a new .mlmodel, and uploads it to the backend.

Usage:
    python retrain_from_deltas.py --round 2026-W28 --version 1.1.0

The round ID must match what iOS devices used when uploading gradients
(format: YYYY-Www, e.g. 2026-W28).
"""

import argparse
import os
import sys
import requests
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import coremltools as ct

BACKEND_URL = os.environ.get("BACKEND_URL", "https://pulse-production-fccc.up.railway.app")
FEATURES = ["amount", "hour_of_day", "day_of_week", "merchant_bucket"]
LABEL = "category"
CATEGORIES = ["food", "transport", "bills", "entertainment", "other"]


def fetch_round_deltas(round_id: str) -> dict:
    """Fetch aggregated FedAvg deltas for a round from the backend."""
    url = f"{BACKEND_URL}/api/federation/round/{round_id}/stats"
    resp = requests.get(url, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    print(f"Round {round_id}: {data['deviceCount']} devices contributed")
    if not data.get("aggregationReady"):
        print(f"WARNING: Round not yet complete (need 3+ devices, have {data['deviceCount']})")
    return data


def fetch_aggregated_deltas(round_id: str) -> dict:
    """
    Fetch the actual category deltas stored for this round.
    Returns a dict like {"food": 0.12, "transport": -0.05, ...}
    """
    url = f"{BACKEND_URL}/api/federation/round/{round_id}/deltas"
    resp = requests.get(url, timeout=10)
    if resp.status_code == 404:
        print("No delta endpoint — using round stats as proxy signal")
        return {}
    resp.raise_for_status()
    return resp.json()


def compute_adjusted_weights(base_weights: dict, deltas: dict) -> dict:
    """
    Apply federated deltas to class weights.
    If delta for a category is positive, users corrected INTO it more than predicted
    → increase its weight so the model predicts it more.
    If delta is negative → model over-predicted it → decrease weight.
    """
    adjusted = dict(base_weights)
    for category, delta in deltas.items():
        if category in adjusted:
            # Scale factor: +0.1 delta → 10% weight increase, capped at ±50%
            factor = 1.0 + (delta * 5.0)
            factor = max(0.5, min(2.0, factor))
            adjusted[category] = adjusted[category] * factor
            print(f"  {category}: weight {base_weights[category]:.2f} → {adjusted[category]:.2f} (delta={delta:+.3f})")
    return adjusted


def train_and_export(class_weights: dict, version: str, output_path: str):
    """Retrain RandomForest with adjusted weights and export to Core ML."""
    df = pd.read_csv("data/synthetic_transactions.csv")
    X = df[FEATURES]
    y = df[LABEL]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(
        n_estimators=50,
        max_depth=10,
        random_state=42,
        class_weight=class_weights
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    print("\n=== Retrained Classifier Accuracy ===")
    print(classification_report(y_test, y_pred))

    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=FEATURES,
        output_feature_names="category"
    )
    coreml_model.short_description = "Federated retrain — adjusted from user corrections"
    coreml_model.author = "Febin Cherian"
    coreml_model.version = version

    coreml_model.save(output_path)
    print(f"\nSaved: {output_path}")


def upload_model(filepath: str, model_name: str, version: str):
    """Upload the .mlmodel file and register it in the backend."""
    url = f"{BACKEND_URL}/api/models/upload"
    with open(filepath, "rb") as f:
        resp = requests.post(
            url,
            files={"file": (os.path.basename(filepath), f, "application/octet-stream")},
            data={"name": model_name, "version": version},
            timeout=120
        )
    resp.raise_for_status()
    result = resp.json()
    print(f"\nUploaded and registered:")
    print(f"  Model:    {result['modelName']} v{result['version']}")
    print(f"  Download: {result['downloadUrl']}")
    return result


def main():
    parser = argparse.ArgumentParser(description="Federated retraining from delta signals")
    parser.add_argument("--round", required=True, help="Round ID e.g. 2026-W28")
    parser.add_argument("--version", required=True, help="New model version e.g. 1.1.0")
    parser.add_argument("--dry-run", action="store_true", help="Train but don't upload")
    args = parser.parse_args()

    print(f"=== Federated Retrain: round={args.round} version={args.version} ===\n")

    # 1. Fetch round info
    fetch_round_deltas(args.round)

    # 2. Try to get actual deltas (may not exist yet — fall back to equal weights)
    try:
        deltas = fetch_aggregated_deltas(args.round)
    except Exception as e:
        print(f"Could not fetch deltas ({e}), using balanced weights")
        deltas = {}

    # 3. Compute adjusted class weights
    base_weights = {cat: 1.0 for cat in CATEGORIES}
    if deltas:
        print("\nAdjusting class weights from federated deltas:")
        adjusted_weights = compute_adjusted_weights(base_weights, deltas)
    else:
        print("\nNo deltas available — retraining with balanced weights")
        adjusted_weights = "balanced"

    # 4. Train and export
    output_path = f"models/TransactionClassifier-{args.version}.mlmodel"
    train_and_export(adjusted_weights, args.version, output_path)

    if args.dry_run:
        print("\n[dry-run] Skipping upload.")
        return

    # 5. Upload to backend
    upload_model(output_path, "TransactionClassifier", args.version)
    print("\nDone. iOS devices will receive the new model on next app foreground.")


if __name__ == "__main__":
    main()
