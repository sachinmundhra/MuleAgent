# Import python packages

import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col 
 
# Write directly to the app

st.title(f"Accounts Detail")

st.write(

  """Details of Accounts - Greens Bank

  """

)


session = get_active_session()
 

my_dataframe = session.table("ACCOUNTS") \
    .select(col("ACCOUNT_ID"), col("CUSTOMER_ID"), col("OPEN_DATE"),col('KYC_LEVEL'),col('ACCOUNT_STATUS')) \
    .sort(col("ACCOUNT_ID").asc()) \
    .limit(1000) \
    #.show()


editable_df = st.data_editor(my_dataframe)

