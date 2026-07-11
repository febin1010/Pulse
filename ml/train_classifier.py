"""
Trains a RandomForest transaction classifier and exports it as a Core ML model.
Output: models/TransactionClassifier.mlmodel
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import coremltools as ct

df = pd.read_csv("data/synthetic_transactions.csv")

FEATURES = ["amount", "hour_of_day", "day_of_week", "merchant_bucket"]
LABEL = "category"

X = df[FEATURES]
y = df[LABEL]

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = RandomForestClassifier(
    n_estimators=50,
    max_depth=10,
    random_state=42,
    class_weight="balanced"
)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
print("=== Classifier Accuracy ===")
print(classification_report(y_test, y_pred))

# Export to Core ML
coreml_model = ct.converters.sklearn.convert(
    model,
    input_features=FEATURES,
    output_feature_names="category"
)

coreml_model.short_description = "Classifies transactions into food, transport, bills, entertainment, other"
coreml_model.author = "Febin Cherian"
coreml_model.version = "1.0.0"

coreml_model.save("models/TransactionClassifier.mlmodel")
print("\nSaved: models/TransactionClassifier.mlmodel")
