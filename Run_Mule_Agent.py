import streamlit as st
from snowflake.snowpark.context import get_active_session
#import pandas as pd

st.set_page_config(page_title="Mule AI Agent Monitor", layout="wide")

# Centered Title
st.markdown(
    "<h1 style='text-align: center;'>Mule AI Agent Monitoring Dashboard</h1>",
    unsafe_allow_html=True
)

session = get_active_session()

# -------------------------------
# 1️⃣ Manual Trigger Section
# -------------------------------
st.subheader("🔄 Manually Run Mule Agent")

if st.button("Run Mule Agent Now"):
    #session.sql("CALL MULE_AGENT_TASK();").collect()
    session.sql("EXECUTE TASK MULE_AGENT_TASK").collect()
    st.success("Mule Agent executed successfully!")

# -------------------------------
# 2️⃣ Task Status Section
# -------------------------------
st.subheader("📌 Task Status")

task_status = session.sql("""
    SHOW TASKS LIKE 'MULE_AGENT_TASK' IN SCHEMA MULEACCOUNT.PUBLIC;
""").to_pandas()

if not task_status.empty:
    st.dataframe(task_status)
else:
    st.warning("Task not found.")

# -------------------------------
# 3️⃣ Task Execution History
# -------------------------------
st.subheader("📊 Task Execution History (Last 5 Runs)")

history = session.sql("""
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME=>'MULE_AGENT_TASK',
    RESULT_LIMIT=>5
))
ORDER BY SCHEDULED_TIME DESC;
""").to_pandas()

st.dataframe(history)

# -------------------------------
# 5️⃣ Auto Refresh Option
# -------------------------------
#st.sidebar.header("⚙️ Controls")
#refresh = st.sidebar.checkbox("Auto Refresh (30 sec)")

#if refresh:
#    st.rerun()

if st.button("Refresh Page"):
    st.rerun()
