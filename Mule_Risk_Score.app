# Import python packages

import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col , when_matched
 
# Write directly to the app

st.title(f"Mule Risk Score")

st.write(

  """Details of Risk transactions of Greens Bank

  """

)
 
session = get_active_session()
 
 
#my_dataframe = session.table("MULE_RISK_SCORES").select(col('ACCOUNT_ID'),col('RISK_SCORE'),col('RISK_LABEL')).distinct()
#my_dataframe = session.table("MULE_RISK_SCORES").select(col('ACCOUNT_ID'),col('RISK_SCORE'),col('RISK_LABEL'),col('SCORE_TS'))

#from snowflake.snowpark.functions import col

my_dataframe = session.table("MULE_RISK_SCORES") \
    .select(col("ACCOUNT_ID"), col("RISK_SCORE"), col("RISK_LABEL")) \
    .sort(col("SCORE_TS").desc()) \
    .limit(100) \
    #.show()


editable_df = st.data_editor(my_dataframe)
 
if my_dataframe:

    refresh = st.button('Refresh')

    if refresh:

        mrs_dataset = session.table("MULE_RISK_SCORES")

        edited_dataset = session.create_dataframe(editable_df)

        try:

            mrs_dataset.merge(edited_dataset

                             , (mrs_dataset['ACCOUNT_ID'] == edited_dataset['ACCOUNT_ID'])

                             , [when_matched().update({'RISK_SCORE': edited_dataset['RISK_SCORE']})]

                            )

            st.success('Data Refreshed !',icon="👍")

        except:

            st.write('Something went wrong')

else:

    st.write('There are no more updated rows !',icon="👍")
  
