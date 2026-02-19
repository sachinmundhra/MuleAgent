# Import python packages
import streamlit as st
from snowflake.snowpark.context import get_active_session
import snowflake.snowpark as snowpark
from snowflake.snowpark.functions import col
from snowflake.snowpark import Session
from sklearn.ensemble import IsolationForest

import streamlit as st

st.markdown("""
<style>
div.stButton > button:first-child {
    background-color: #29B5E8;   /* Snowflake blue */
    color: white;
    border-radius: 8px;
    height: 45px;
    width: 200px;
    font-size: 16px;
    font-weight: bold;
}
div.stButton > button:first-child:hover {
    background-color: #1F8FBF;
    color: white;
}
</style>
""", unsafe_allow_html=True)

#if st.button("Register Model"):
#    st.success("Model registered successfully!")


st.title("Detect Mule Accounts ")

st.write("Register a Machine Learning Model")

# Get the current credentials
session = get_active_session()

#st.title("Enter Model Name")
txn_id = st.text_input("Enter Model Name")

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


if st.button("Train & Register Model"):
    # Train model

    model = IsolationForest(
        n_estimators=200, # No of Tress , value of 200 is ideal for banking frauds
        contamination=0.02, # Used to define the anomaly threads 
        random_state=42 
    )
    df["ANOMALY_SCORE"] = model.fit_predict(df[feature_cols])

    import os
    import joblib

    
    # Return value will appear in the Results tab.
    joblib.dump(model, "/tmp/mule_model.joblib")
    session.file.put(
        "/tmp/mule_model.joblib",
        "@MULE",
        overwrite=True
    )

    
    #model = "your_model_object" # Replace with your actual model
    #filename = os.path.join(output_dir, 'model.joblib')
    #joblib.dump(model, filename)

    
    #MULEACCOUNT.PUBLIC.MULE
    
    #return dataframe

    
    st.success("🚀 Model registered in Snowflake Model Registry!")
    #st.write(mv)



