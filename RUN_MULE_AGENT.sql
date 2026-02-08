CREATE OR REPLACE PROCEDURE RUN_MULE_AGENT()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = 3.10
PACKAGES = ('snowflake-snowpark-python','scikit-learn','joblib','pandas','numpy')
HANDLER = 'run'
AS
$$
from snowflake.snowpark import Session
import pandas as pd
import joblib
import numpy as np
import os

def run(session: Session):

    # -----------------------------
    # Step 1: Rebuild FEATURE_STORE
    # -----------------------------
    session.sql("""
        CREATE OR REPLACE TABLE FEATURE_STORE AS
        SELECT
            t.ACCOUNT_ID,
            COUNT(*) AS TOTAL_TXNS,
            COUNT(DISTINCT DATE(t.TXN_TS)) AS ACTIVE_DAYS,
            SUM(t.AMOUNT) AS TOTAL_AMOUNT,

            SUM(CASE WHEN t.TXN_TYPE='CREDIT' THEN t.AMOUNT ELSE 0 END) AS TOTAL_CREDIT,
            SUM(CASE WHEN t.TXN_TYPE='DEBIT'  THEN t.AMOUNT ELSE 0 END) AS TOTAL_DEBIT,

            CASE 
                WHEN SUM(CASE WHEN t.TXN_TYPE='CREDIT' THEN t.AMOUNT END) = 0
                THEN 0
                ELSE
                SUM(CASE WHEN t.TXN_TYPE='DEBIT' THEN t.AMOUNT END) /
                SUM(CASE WHEN t.TXN_TYPE='CREDIT' THEN t.AMOUNT END)
            END AS FLOW_RATIO,

            COUNT(DISTINCT t.COUNTERPARTY_ID) AS UNIQUE_COUNTERPARTIES,
            COUNT(DISTINCT t.DEVICE_ID) AS DEVICE_COUNT,
            COUNT(DISTINCT t.IP_ADDRESS) AS IP_COUNT,

            DATEDIFF(day, a.OPEN_DATE, CURRENT_DATE()) AS ACCOUNT_AGE_DAYS,
            CASE WHEN a.KYC_LEVEL='MIN_KYC' THEN 1 ELSE 0 END AS LOW_KYC_FLAG

        FROM TRANSACTIONS t
        JOIN ACCOUNTS a
          ON t.ACCOUNT_ID = a.ACCOUNT_ID
        GROUP BY t.ACCOUNT_ID, a.OPEN_DATE, a.KYC_LEVEL
    """).collect()

    # -----------------------------
    # Step 2: Load Features
    # -----------------------------
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

    # -----------------------------
    # Step 3: Load Model
    # -----------------------------
    session.file.get(
        "@MULE/mule_model.joblib.gz",
        "/tmp"
    )

    model = joblib.load("/tmp/mule_model.joblib.gz")

    # -----------------------------
    # Step 4: Score Accounts
    # -----------------------------
    df["RISK_SCORE"] = model.decision_function(df[feature_cols])
    df["RISK_LABEL"] = np.where(df["RISK_SCORE"] < 0, "MULE_SUSPECT", "NORMAL")
    df["SCORE_TS"] = pd.Timestamp.now().strftime("%B %d, %Y, %I:%M %p")

    # -----------------------------
    # Step 5: Persist Scores
    # -----------------------------
    session.write_pandas(
        df[["ACCOUNT_ID","RISK_SCORE","RISK_LABEL","SCORE_TS"]],
        "MULE_RISK_SCORES",
        auto_create_table=False,
        overwrite=False
    )

    return "Mule Agent executed successfully"
$$;
