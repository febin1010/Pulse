"""
Trains an IsolationForest anomaly detector and exports it as a Core ML model.
Output: models/AnomalyDetector.mlmodel
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import LabelEncoder
import coremltools as ct

df = pd.read_csv("data/synthetic_transactions.csv")

le = LabelEncoder()
df["category_encoded"] = le.fit_transform(df["category"])

FEATURES = ["amount", "hour_of_day", "day_of_week", "merchant_bucket", "category_encoded"]

X = df[FEATURES]

model = IsolationForest(
    n_estimators=100,
    contamination=0.05,
    random_state=42
)
model.fit(X)

scores = model.decision_function(X)
predictions = model.predict(X)
anomaly_count = (predictions == -1).sum()
print(f"Flagged {anomaly_count} anomalies out of {len(df)} ({anomaly_count/len(df)*100:.1f}%)")

# IsolationForest can't be directly exported via sklearn converter.
# We export using a pipeline wrapper approach with coremltools.
# For the iOS app, we use the score threshold approach:
# anomaly_score > threshold => normal, anomaly_score <= threshold => anomaly

threshold = float(np.percentile(scores, 5))
print(f"Anomaly threshold (5th percentile): {threshold:.4f}")

# Save threshold for use in iOS app
import json
with open("models/anomaly_config.json", "w") as f:
    json.dump({
        "threshold": threshold,
        "features": FEATURES,
        "version": "1.0.0"
    }, f, indent=2)

# Export the underlying decision trees via a LinearSVC proxy
# Since IsolationForest doesn't export directly, we train a classifier
# on its predictions to create an exportable proxy model
from sklearn.ensemble import GradientBoostingClassifier

y_labels = (predictions == -1).astype(int)
proxy = GradientBoostingClassifier(n_estimators=30, max_depth=4, random_state=42)
proxy.fit(X, y_labels)

proxy_accuracy = proxy.score(X, y_labels)
print(f"Proxy model accuracy: {proxy_accuracy:.2%}")

coreml_model = ct.converters.sklearn.convert(
    proxy,
    input_features=FEATURES,
    output_feature_names="is_anomaly"
)

coreml_model.short_description = "Detects anomalous transactions (1=anomaly, 0=normal)"
coreml_model.author = "Febin Cherian"
coreml_model.version = "1.0.0"

coreml_model.save("models/AnomalyDetector.mlmodel")
print("Saved: models/AnomalyDetector.mlmodel")
print("Saved: models/anomaly_config.json")
