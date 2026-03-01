# Import python packages

import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col , when_matched
 
# Write directly to the app

st.title(f"Mule Risk Score Screen")
#st.markdown(
#    "<h1 style='text-align: center;'>Mule Risk Score</h1>",
#    unsafe_allow_html=True
#)

st.markdown("<span style='color:red;text-align:center'>Risk Score < 0 - Account is MULE_SUSPECT </span>", unsafe_allow_html=True)
st.markdown("<span style='color:blue;'>Risk Score > 0 - Account is NORMAL </span>", unsafe_allow_html=True)

st.markdown("""
    <style>
    /* Data Editor Header Styling */
    div[data-testid="stDataEditor"] thead tr th {
        background-color: #006400 !important;   /* Header Background */
        color: white !important;                /* Header Text Color */
        font-size: 16px !important;             /* Header Font Size */
        text-align: center !important;          /* Center Align */
    }
    </style>
""", unsafe_allow_html=True)


session = get_active_session()
 

my_dataframe = session.table("MULE_RISK_SCORES") \
    .select(col("ACCOUNT_ID"), col("RISK_SCORE"), col("RISK_LABEL"),col('SCORE_TS')) \
    .sort(col("RISK_LABEL").asc()) \
    .limit(5000) \
    #.show()

#editable_df = st.data_editor(my_dataframe)

df = my_dataframe.to_pandas()

if df.empty:
    st.success("✅ No HIGH risk mule accounts found.")
    st.stop()
    
def highlight_rows(row):
    if row["RISK_LABEL"] == "MULE_SUSPECT":
        return ['background-color: #ffcccc'] * len(row)  # Light Red
    elif row["RISK_LABEL"] == "NORMAL":
        return ['background-color: #cce5ff'] * len(row)  # Light Green
    else:
        return [''] * len(row)

styled_df = df.style.apply(highlight_rows, axis=1)

st.dataframe(styled_df, use_container_width=True)

