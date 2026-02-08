import streamlit as st
import uuid
import snowflake.connector
from datetime import datetime
from datetime import datetime


# ----------------------------------
# Snowflake Connection Config
# ----------------------------------
SNOWFLAKE_CONFIG = {
    "user": "ACME_ADMIN",
    "password": "MarolNaka@0803",
    "account": "QNGYAPF-ACME",
    "warehouse": "ACME_WH",
    "database": "MULEACCOUNT",
    "schema": "PUBLIC",
}

# -----------------------------
# Snowflake Connection
# -----------------------------
def get_connection():
    return snowflake.connector.connect(
        "user": "ACME_ADMIN",
        "password": "MarolNaka@0803",
        "account": "QNGYAPF-ACME",
        "warehouse": "ACME_WH",
        "database": "MULEACCOUNT",
        "schema": "PUBLIC"
    )


#def get_connection():
 #   return snowflake.connector.connect(**SNOWFLAKE_CONFIG)

# ----------------------------------
# Streamlit UI
# ----------------------------------
st.set_page_config(page_title="Transaction Ingestion", layout="centered")
st.title("💳 Insert Transaction Record")

with st.form("txn_form"):
    txn_id = st.text_input("Transaction ID")
    account_id = st.text_input("Account ID")
    txn_ts = st.date_input("Transaction Date")
    txn_time = st.time_input("Transaction Time")
    txn_type = st.selectbox("Transaction Type", ["CREDIT", "DEBIT"])
    amount = st.number_input("Amount", min_value=0.0, step=100.0)
    counterparty_id = st.text_input("Counterparty ID")
    channel = st.selectbox("Channel", ["UPI", "IMPS", "NEFT"])
    device_id = st.text_input("Device ID")
    ip_address = st.text_input("IP Address")

    submit = st.form_submit_button("Insert Transaction")

# ----------------------------------
# Insert Logic
# ----------------------------------
if submit:
    if not txn_id or not account_id:
        st.error("Transaction ID and Account ID are mandatory")
    else:
        try:
            conn = get_connection()
            cur = conn.cursor()

            txn_timestamp = datetime.combine(txn_ts, txn_time)

            insert_sql = """
                INSERT INTO TRANSACTIONS (
                    TXN_ID,
                    ACCOUNT_ID,
                    TXN_TS,
                    TXN_TYPE,
                    AMOUNT,
                    COUNTERPARTY_ID,
                    CHANNEL,
                    DEVICE_ID,
                    IP_ADDRESS
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """

            cur.execute(
                insert_sql,
                (
                    txn_id,
                    account_id,
                    txn_timestamp,
                    txn_type,
                    amount,
                    counterparty_id,
                    channel,
                    device_id,
                    ip_address
                )
            )

            conn.commit()
            st.success("✅ Transaction inserted successfully")

        except Exception as e:
            st.error(f"❌ Error inserting record: {e}")

        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
