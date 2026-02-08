import streamlit as st
import uuid
import snowflake.connector
from datetime import datetime
import os
import joblib
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
from snowflake.snowpark.functions import col
from snowflake.snowpark import Session
from sklearn.ensemble import IsolationForest
# ----------------------------------
# Streamlit UI
# ----------------------------------
#st.set_page_config(page_title="Transaction Ingestion", layout="centered")
#st.title("Model Registration")

import streamlit as st
import pandas as pd
import joblib
import os

from snowflake.snowpark import Session
from snowflake.snowpark.context import get_active_session

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split

from snowflake.ml.registry import Registry


# Use st.connection() to manage the Snowflake session
#conn = st.connection("snowflake")
#session = conn.session()

# ----------------------------------
# Snowflake Connection Config
# ----------------------------------
SNOWFLAKE_CONFIG = {
    "user": "ACME_ADMIN",
    "password": "MarolNaka@0803",
    "account": "QNGYAPF-ACME",
    "warehouse": "ACME_WH",
    "database": "MULEACCOUNT",
    "schema": "PUBLIC",
}

def get_connection():
    return snowflake.connector.connect(**SNOWFLAKE_CONFIG)

st.set_page_config(page_title="Snowflake Model Registration", layout="wide")
st.title("📦 Model Registration in Snowflake")

# -------------------------------------------------------------------
# Get active Snowflake session (Streamlit in Snowflake)
# -------------------------------------------------------------------
session = get_connection()

df = session.table("FEATURE_STORE").to_pandas()

feature_cols = [
        "TOTAL_TXNS",
        "ACTIVE_DAYS",
        "TOTAL_AMOUNT",
        "TOTAL_CREDIT",
        "TOTAL_DEBIT",
        "FLOW_RATIO",
        "UNIQUE_COUNTERPARTIES",
        "DEVICE_COUNT",
        "IP_COUNT",
        "ACCOUNT_AGE_DAYS",
        "LOW_KYC_FLAG"
 ]

model = IsolationForest(
        n_estimators=200,
        contamination=0.02,
        random_state=42
    )
df["ANOMALY_SCORE"] = model.fit_predict(df[feature_cols])

    
    # Return value will appear in the Results tab.
 joblib.dump(model, "/tmp/mule_model.joblib")
 session.file.put(
      "/tmp/mule_model.joblib",
       "@MULE",
       overwrite=True
  )
   

