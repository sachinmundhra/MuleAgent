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

df = session.table("MULEACCOUNT.PUBLIC.FEATURE_STORE").to_pandas()


