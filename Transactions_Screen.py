# Import python packages

import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col 
 
# Write directly to the app

st.title(f"Transaction Detail")

st.write(

  """Details of Transaction - Greens Bank Accounts

  """

)

session = get_active_session()
 

my_dataframe = session.table("TRANSACTIONS") \
    .select(col("ACCOUNT_ID"), col("TXN_TS"), col("TXN_TYPE"),col('AMOUNT'),col('COUNTERPARTY_ID'),col('CHANNEL'),col('DEVICE_ID'),col('IP_ADDRESS')) \
    .sort(col("ACCOUNT_ID").asc()) \
    .limit(1000) \
    #.show()


editable_df = st.data_editor(my_dataframe)

