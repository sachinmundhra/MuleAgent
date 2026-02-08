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
st.set_page_config(page_title="Transaction Ingestion", layout="centered")
st.title("Model Registration")
