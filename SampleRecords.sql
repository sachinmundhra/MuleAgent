INSERT INTO ACCOUNTS
SELECT
    'ACC' || LPAD(SEQ4(), 6, '0') AS ACCOUNT_ID,
    'CUST' || LPAD(UNIFORM(1, 5000, RANDOM()), 5, '0') AS CUSTOMER_ID,
    
    -- Recent accounts (higher mule probability)
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 20 
        THEN DATEADD(DAY, -UNIFORM(1,30,RANDOM()), CURRENT_DATE())
        ELSE DATEADD(DAY, -UNIFORM(30,1500,RANDOM()), CURRENT_DATE())
    END AS OPEN_DATE,
    
    -- Lower KYC more prone to mule
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 15 THEN 'LOW'
        WHEN UNIFORM(1,100,RANDOM()) <= 40 THEN 'MIN'
        ELSE 'FULL'
    END AS KYC_LEVEL,
    
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 5 THEN 'BLOCKED'
        ELSE 'ACTIVE'
    END AS ACCOUNT_STATUS

FROM TABLE(GENERATOR(ROWCOUNT => 10000));


delete from TRANSACTIONS;

delete from FEATURE_STORE;

delete from MULE_RISK_SCORES;

INSERT INTO TRANSACTIONS
SELECT
    'TXN' || LPAD(SEQ4(), 8, '0') AS TXN_ID,
    
    -- Random account mapping
    'ACC' || LPAD(UNIFORM(0,9999,RANDOM()), 6, '0') AS ACCOUNT_ID,
    
    DATEADD(
        SECOND,
        -UNIFORM(0, 864000, RANDOM()),  -- last 10 days
        CURRENT_TIMESTAMP()
    ) AS TXN_TS,
    
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 45 THEN 'CREDIT'
        ELSE 'DEBIT'
    END AS TXN_TYPE,
    
    -- Large amounts for mule pattern simulation
    CASE 
        WHEN UNIFORM(1,100,RANDOM()) <= 10 
        THEN ROUND(UNIFORM(50000,200000,RANDOM()),2)
        ELSE ROUND(UNIFORM(100,20000,RANDOM()),2)
    END AS AMOUNT,
    
    'CP' || LPAD(UNIFORM(1,8000,RANDOM()), 6, '0') AS COUNTERPARTY_ID,
    
    CASE 
        WHEN UNIFORM(1,3,RANDOM()) = 1 THEN 'UPI'
        WHEN UNIFORM(1,3,RANDOM()) = 2 THEN 'IMPS'
        ELSE 'NEFT'
    END AS CHANNEL,
    
    -- Device reuse simulation
    'DEV' || LPAD(UNIFORM(1,2000,RANDOM()), 4, '0') AS DEVICE_ID,
    
    -- IP reuse simulation
    '192.168.' || UNIFORM(1,255,RANDOM()) || '.' || UNIFORM(1,255,RANDOM()) AS IP_ADDRESS

FROM TABLE(GENERATOR(ROWCOUNT => 20000));


CREATE OR REPLACE TEMP TABLE MULE_ACCOUNTS AS
SELECT ACCOUNT_ID
FROM ACCOUNTS
ORDER BY RANDOM()
LIMIT 200;

INSERT INTO TRANSACTIONS
SELECT
    'TXN_MULE' || SEQ4(),
    ACCOUNT_ID,
    CURRENT_TIMESTAMP(),
    'CREDIT',
    ROUND(UNIFORM(100000,300000,RANDOM()),2),
    'SUSP_CP',
    'IMPS',
    'DEV9999',
    '10.10.10.10'
FROM MULE_ACCOUNTS;



CREATE OR REPLACE PROCEDURE MULEACCOUNT.PUBLIC.RUN_MULE_AGENT()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python','scikit-learn','joblib','pandas','numpy')
HANDLER = 'run'
COMMENT='user-defined procedure'
EXECUTE AS OWNER
AS '
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

            SUM(CASE WHEN t.TXN_TYPE=''CREDIT'' THEN t.AMOUNT ELSE 0 END) AS TOTAL_CREDIT,
            SUM(CASE WHEN t.TXN_TYPE=''DEBIT''  THEN t.AMOUNT ELSE 0 END) AS TOTAL_DEBIT,

            CASE 
                WHEN SUM(CASE WHEN t.TXN_TYPE=''CREDIT'' THEN t.AMOUNT END) = 0
                THEN 0
                ELSE
                SUM(CASE WHEN t.TXN_TYPE=''DEBIT'' THEN t.AMOUNT END) /
                SUM(CASE WHEN t.TXN_TYPE=''CREDIT'' THEN t.AMOUNT END)
            END AS FLOW_RATIO,

            COUNT(DISTINCT t.COUNTERPARTY_ID) AS UNIQUE_COUNTERPARTIES,
            COUNT(DISTINCT t.DEVICE_ID) AS DEVICE_COUNT,
            COUNT(DISTINCT t.IP_ADDRESS) AS IP_COUNT,

            DATEDIFF(day, a.OPEN_DATE, CURRENT_DATE()) AS ACCOUNT_AGE_DAYS,
            CASE WHEN a.KYC_LEVEL=''MIN_KYC'' THEN 1 ELSE 0 END AS LOW_KYC_FLAG

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
    df["RISK_LABEL"] = np.where(df["RISK_SCORE"] < 0.05, "MULE_SUSPECT", "NORMAL")
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
';




select * from MULE_RISK_SCORES where RISK_LABEL = 'MULE_SUSPECT'

select * from MULE_RISK_SCORES where RISK_SCORE < 0.05;
