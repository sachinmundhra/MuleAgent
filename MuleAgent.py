# The Snowpark package is required for Python Worksheets. 
# You can add more packages by selecting them using the Packages control and then importing them.

import os
import joblib
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
#import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
from snowflake.snowpark import Session
from sklearn.ensemble import IsolationForest


def main(session: snowpark.Session): 
    # Your code goes here, inside the "main" handler.
    tableName = 'information_schema.packages'
    dataframe = session.table(tableName).filter(col("language") == 'python')

    # Print a sample of the dataframe to standard output.
    dataframe.show()

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
   
    #MULEACCOUNT.PUBLIC.MULE

    
    # Return value will appear in the Results tab.
    return dataframe
