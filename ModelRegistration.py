import streamlit as st
import pandas as pd
import joblib

from snowflake.snowpark.context import get_active_session
from snowflake.ml.registry import Registry
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from snowflake.ml.registry import Registry


# -------------------------------------------------
# Streamlit UI
# -------------------------------------------------
st.title("📦 Snowflake Model Registration")

st.write("Train and register a model in Snowflake Model Registry")

# -------------------------------------------------
# Snowflake Session
# -------------------------------------------------
session = get_active_session()

# -------------------------------------------------
# Sample Training Data
# -------------------------------------------------
data = pd.DataFrame({
    "age": [22, 35, 45, 52, 23, 40],
    "txn_count": [5, 50, 200, 150, 10, 180],
    "is_mule": [0, 0, 1, 1, 0, 1]
})

X = data[["age", "txn_count"]]
y = data["is_mule"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42
)

# -------------------------------------------------
# Train Model
# -------------------------------------------------
model = RandomForestClassifier(
    n_estimators=50,
    random_state=42
)
model.fit(X_train, y_train)

# -------------------------------------------------
# Register Model Button
# -------------------------------------------------
if st.button("🚀 Register Model"):
    registry = Registry(
        session=session,
        database_name="ML_DB",
        schema_name="ML_SCHEMA"
    )

    model_name = "MULE_ACCOUNT_RF"

    registry.log_model(
        model,
        model_name=model_name,
        version_name="v1",
        sample_input_data=X_train,
        comment="RandomForest model for Mule Account Detection",
        tags={
            "domain": "fraud",
            "use_case": "mule_account",
            "algo": "random_forest"
        }
    )

    st.success(f"✅ Model `{model_name}` registered successfully!")
