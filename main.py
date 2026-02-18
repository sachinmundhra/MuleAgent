import streamlit as st
import snowflake.connector
from datetime import datetime
import re

# -----------------------------
# Snowflake Connection
# -----------------------------
def get_snowflake_connection():
    return snowflake.connector.connect(
        user="sachinmundhra",
        password="MarolNaka@0803",
        account="QNGYAPF-YOB34856",
        warehouse="COMPUTE_WH",
        database="MULEACCOUNT",
        schema="PUBLIC"
    )

# -----------------------------
# Fetch Account IDs
# -----------------------------
def fetch_account_ids(conn):
    query = "SELECT ACCOUNT_ID FROM ACCOUNTS WHERE ACCOUNT_STATUS = 'ACTIVE'"
    cur = conn.cursor()
    cur.execute(query)
    rows = cur.fetchall()
    return [row[0] for row in rows]

# -----------------------------
# Generate TXN_ID using sequence
# -----------------------------
def generate_txn_id(conn):
    cur = conn.cursor()
    cur.execute("SELECT TXN_SEQ.NEXTVAL")
    seq_val = cur.fetchone()[0]
    return f"TXN{str(seq_val).zfill(3)}"

# -----------------------------
# Account balance check
# -----------------------------
def get_account_balance(conn, account_id):
    cur = conn.cursor()

    balance_sql = """
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN TXN_TYPE = 'CREDIT' THEN AMOUNT
                WHEN TXN_TYPE = 'DEBIT' THEN -AMOUNT
            END
        ), 0) AS BALANCE
    FROM TRANSACTIONS
    WHERE ACCOUNT_ID = %s
    """

    cur.execute(balance_sql, (account_id,))
    balance = cur.fetchone()[0]

    return balance

# -----------------------------
# Insert Transaction
# -----------------------------
from datetime import datetime

#def insert_transaction(conn, txn_id, account_id, txn_type, amount, channel):
#def insert_transaction(conn, account_id, txn_type, amount, sender_id , channel, device_id):
#    cur = conn.cursor()
#
#    insert_sql = """
#    INSERT INTO TRANSACTIONS (
#        TXN_ID,
#        ACCOUNT_ID,
#        TXN_TS,
#        TXN_TYPE,
#        AMOUNT,
#        COUNTERPARTY_ID,
#        CHANNEL,
#        DEVICE_ID,
#        IP_ADDRESS
 #   )
 #   VALUES (%s, %s, %s, %s, %s, %s, %s, %s,%s)
 #   """

    #cur.execute(
     #   insert_sql,
     #   (
     #       txn_id,
     #       account_id,
     #       datetime.now(),     
     #       txn_type,
     #       amount,
     #       COUNTERPARTY_ID,
     #       channel,
     #       device_id,       
     #       "127.0.0.1"        
     #   )
        
      
    #)

    #conn.commit()


def insert_transaction(conn, account_id, txn_type, amount, sender_id , channel, device_id):
    cur = conn.cursor()

    sql = """
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
    SELECT
        'TXN' || LPAD(MULEACCOUNT.PUBLIC.TXN_SEQ.NEXTVAL, 3, '0'),
        %s,
        CURRENT_TIMESTAMP(),
        %s,
        %s,
        %s,
        %s,
        %s,            -- DEVICE_ID from dropdown
        '127.0.0.1'
    """

    cur.execute(sql, (
        account_id,
        txn_type,
        amount,
        sender_id,
        channel,
        device_id
    ))

    conn.commit()


# -----------------------------
# Streamlit UI
# -----------------------------
st.set_page_config(
    page_title="Green Bank",
    page_icon="🏦",
    layout="centered"
)

# Custom CSS for better UI
st.markdown("""
<style>
.main {
    background-color: #f7f9fc;
}
.title {
    text-align: center;
    font-size: 40px;
    font-weight: bold;
    color: #1f4e79;
    margin-bottom: 30px;
}
.stButton>button {
    background-color: #1f4e79;
    color: white;
    font-size: 18px;
    padding: 8px 25px;
    border-radius: 8px;
}
</style>
""", unsafe_allow_html=True)

st.markdown('<div class="title">🏦 GREENS BANK</div>', unsafe_allow_html=True)

# -----------------------------
# Main Form
# -----------------------------
try:
    conn = get_snowflake_connection()
    account_ids = fetch_account_ids(conn)

    with st.form("transaction_form"):
        account_id = st.selectbox(
            "Account ID",
            options=account_ids
        )

        txn_type = st.selectbox(
            "Transaction Type",
            options=["CREDIT", "DEBIT"]
        )

        amount = st.text_input(
            "Amount",
            placeholder="Enter numeric amount"
        )

        sender_id = st.text_input(
            "Sender / Receiver",
            placeholder="Enter Sender / Counterparty ID"
        )
        
        channel = st.selectbox(
            "Channel",
            options=["UPI", "IMPS", "NEFT"]
        )

        device_id = st.selectbox(
            "Device",
            options=["DEVICE1", "DEVICE2", "DEVICE3"]
        )
        
        submit = st.form_submit_button("Submit")

    # -----------------------------
    # Validation + Submit Logic
    # -----------------------------
    if submit:
        if not amount:
            st.error("❌ Amount is required")
        elif not re.match(r"^\d+(\.\d{1,2})?$", amount):
            st.error("❌ Amount must be numeric (up to 2 decimal places)")
        else:
            txn_id = generate_txn_id(conn)
            #def insert_transaction(conn, txn_id , account_id, txn_type, amount, sender_id , channel, device_id):
            insert_transaction(
                conn,
                #txn_id,
                account_id,
                txn_type,
                float(amount),
                sender_id,
                channel,
                device_id
               
            )
 
            st.success(f"✅ Transaction Completed Successfully")
            #st.info(f"Generated Transaction ID: **{txn_id}**")
 
except Exception as e:
    st.error("❌ Error connecting to Snowflake")
    st.code(str(e))
