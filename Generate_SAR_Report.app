import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col
import pandas as pd

# -----------------------------------
# PAGE CONFIG
# -----------------------------------
st.set_page_config(page_title="Mule Account SAR Generator", layout="wide")
st.title("🚨 Mule Account SAR Generation Console")

session = get_active_session()

# -----------------------------------
# LOAD HIGH RISK ACCOUNTS
# -----------------------------------
@st.cache_data
def load_high_risk_accounts():
    query = """
    SELECT 
        r.ACCOUNT_ID,
        r.RISK_SCORE,
        r.RISK_LABEL,
        f.TOTAL_TXNS,
        f.TOTAL_AMOUNT,
        f.DEVICE_COUNT,
        f.UNIQUE_COUNTERPARTIES
    FROM MULE_RISK_SCORES r
    JOIN FEATURE_STORE f
        ON r.ACCOUNT_ID = f.ACCOUNT_ID
    WHERE r.RISK_LABEL = 'MULE_SUSPECT'
    """
    return session.sql(query).to_pandas()

df = load_high_risk_accounts()

if df.empty:
    st.success("✅ No HIGH risk mule accounts found.")
    st.stop()

st.subheader("🔎 High Risk Mule Accounts")
st.dataframe(df, use_container_width=True)

# -----------------------------------
# ACCOUNT SELECTION
# -----------------------------------
selected_account = st.selectbox(
    "Select Account to Generate SAR",
    df["ACCOUNT_ID"].unique()
)

# -----------------------------------
# GENERATE SAR BUTTON
# -----------------------------------
if st.button("Generate SAR"):

    insert_query = f"""
    INSERT INTO SAR_REPORTS
    SELECT
        UUID_STRING() AS SAR_ID,
        r.ACCOUNT_ID,
        'UNKNOWN' AS CUSTOMER_NAME,
        r.RISK_SCORE,
        r.RISK_LABEL,
        CURRENT_TIMESTAMP(),
        ARRAY_TO_STRING(r.REASON_CODES, ', ') AS SUSPICION_REASON,
        f.TOTAL_TXNS,
        f.TOTAL_AMOUNT,
        MIN(t.TXN_TS) AS FIRST_TXN_DATE,
        MAX(t.TXN_TS) AS LAST_TXN_DATE,
        f.DEVICE_COUNT,
        f.UNIQUE_COUNTERPARTIES,
        'PENDING' AS REPORT_STATUS,
        CURRENT_TIMESTAMP()
    FROM MULE_RISK_SCORES r
    JOIN FEATURE_STORE f 
        ON r.ACCOUNT_ID = f.ACCOUNT_ID
    JOIN TRANSACTIONS t 
        ON r.ACCOUNT_ID = t.ACCOUNT_ID
    WHERE r.ACCOUNT_ID = '{selected_account}'
      AND r.RISK_LABEL = 'MULE_SUSPECT'
    GROUP BY 
        r.ACCOUNT_ID,
        r.RISK_SCORE,
        r.RISK_LABEL,
        r.REASON_CODES,
        f.TOTAL_TXNS,
        f.TOTAL_AMOUNT,
        f.DEVICE_COUNT,
        f.UNIQUE_COUNTERPARTIES;
    """

    session.sql(insert_query).collect()

    st.success(f"✅ SAR generated successfully for {selected_account}")

# -----------------------------------
# VIEW GENERATED SARs
# -----------------------------------
st.subheader("📄 Generated SAR Reports")

sar_df = session.sql("""
SELECT *
FROM SAR_REPORTS
ORDER BY CREATED_TS DESC
""").to_pandas()

st.dataframe(sar_df, use_container_width=True)

# -----------------------------------
# SAR NARRATIVE GENERATOR
# -----------------------------------
st.subheader("📝 SAR Narrative")

if not sar_df.empty:
    selected_sar = st.selectbox(
        "Select SAR",
        sar_df["SAR_ID"].unique()
    )

    narrative_query = f"""
    SELECT
        ACCOUNT_ID,
        'Account shows rapid inflow/outflow pattern with '
        || TOTAL_TXNS || ' transactions totaling INR '
        || TOTAL_AMOUNT ||
        '. Multiple devices detected (' || DEVICE_COUNT ||
        ') and high counterparty count (' || UNIQUE_COUNTERPARTIES || ').'
        AS SAR_NARRATIVE
    FROM SAR_REPORTS
    WHERE SAR_ID = '{selected_sar}'
    """

    narrative_df = session.sql(narrative_query).to_pandas()

    if not narrative_df.empty:
        st.text_area(
            "Generated Narrative",
            narrative_df["SAR_NARRATIVE"].iloc[0],
            height=150
        )

# -----------------------------------
# EXPORT CSV
# -----------------------------------
st.subheader("⬇ Export SAR Data")

if st.button("Export SAR CSV"):
    sar_df.to_csv("/tmp/sar_export.csv", index=False)
    with open("/tmp/sar_export.csv", "rb") as file:
        st.download_button(
            label="Download SAR CSV",
            data=file,
            file_name="sar_reports.csv",
            mime="text/csv"
        )
