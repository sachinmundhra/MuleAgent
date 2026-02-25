INSERT INTO MULEACCOUNT.PUBLIC.TRANSACTIONS (
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
WITH BASE AS (
    SELECT
        SEQ4() AS SEQ_ID,
        UNIFORM(1,100,RANDOM()) AS MULE_GROUP
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)

SELECT
    'TXN_' || SEQ_ID                                       AS TXN_ID,

    /* Few accounts handling many transactions (mule concentration) */
    'ACC_MULE_' || LPAD(MULE_GROUP,3,'0')                  AS ACCOUNT_ID,

    /* Rapid activity in recent days */
    DATEADD(
        SECOND,
        -UNIFORM(0, 3*24*60*60, RANDOM()),   -- last 3 days burst
        CURRENT_TIMESTAMP()
    )                                                      AS TXN_TS,

    /* Mostly credit then transfer pattern */
    CASE
        WHEN UNIFORM(1,100,RANDOM()) <= 55 THEN 'CREDIT'
        WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN 'TRANSFER'
        ELSE 'DEBIT'
    END                                                    AS TXN_TYPE,

    /* Structuring behaviour (mostly mid-value repeated amounts) */
    CASE
        WHEN UNIFORM(1,100,RANDOM()) <= 70
            THEN ROUND(UNIFORM(5000, 49000, RANDOM()),2)
        ELSE ROUND(UNIFORM(100, 2000, RANDOM()),2)
    END                                                    AS AMOUNT,

    /* Limited pool of repeat senders/receivers */
    'CP_' || UNIFORM(1,500,RANDOM())                       AS COUNTERPARTY_ID,

    /* Digital heavy channels */
    CASE
        WHEN UNIFORM(1,100,RANDOM()) <= 60 THEN 'UPI'
        WHEN UNIFORM(1,100,RANDOM()) <= 85 THEN 'MOBILE'
        ELSE 'WEB'
    END                                                    AS CHANNEL,

    /* Few devices reused */
    'DEV_SHARED_' || UNIFORM(1,20,RANDOM())                AS DEVICE_ID,

    /* Changing IPs (proxy / different networks) */
    CONCAT(
        UNIFORM(10,200,RANDOM()),'.',
        UNIFORM(0,255,RANDOM()),'.',
        UNIFORM(0,255,RANDOM()),'.',
        UNIFORM(0,255,RANDOM())
    )                                                      AS IP_ADDRESS
FROM BASE;

select * from TRANSACTIONS

   SELECT
        SEQ4() AS SEQ_ID,
        UNIFORM(1,100,RANDOM()) AS MULE_GROUP
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))

    update TRANSACTIONS set ACCOUNT_ID = 'ACC2001' where ACCOUNT_ID in ('ACC_MULE_006','ACC_MULE_007');

      update TRANSACTIONS set ACCOUNT_ID = 'ACC3001' where ACCOUNT_ID like 'ACC_MULE_1%';


------------------------------


CREATE OR REPLACE TABLE MULEACCOUNT.PUBLIC.SAR_REPORTS (
    SAR_ID STRING,
    ACCOUNT_ID STRING,
    CUSTOMER_NAME STRING,
    RISK_SCORE NUMBER(5,2),
    RISK_LABEL STRING,
    ALERT_DATE TIMESTAMP,
    SUSPICION_REASON STRING,
    TOTAL_TXNS NUMBER,
    TOTAL_AMOUNT NUMBER(18,2),
    FIRST_TXN_DATE TIMESTAMP,
    LAST_TXN_DATE TIMESTAMP,
    DEVICE_COUNT NUMBER,
    UNIQUE_COUNTERPARTIES NUMBER,
    REPORT_STATUS STRING,
    CREATED_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

delete from SAR_REPORTS;

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
JOIN FEATURE_STORE f ON r.ACCOUNT_ID = f.ACCOUNT_ID
JOIN TRANSACTIONS t ON r.ACCOUNT_ID = t.ACCOUNT_ID
WHERE r.RISK_LABEL = 'MULE_SUSPECT'
GROUP BY 
    r.ACCOUNT_ID,
    r.RISK_SCORE,
    r.RISK_LABEL,
    r.REASON_CODES,
    f.TOTAL_TXNS,
    f.TOTAL_AMOUNT,
    f.DEVICE_COUNT,
    f.UNIQUE_COUNTERPARTIES;


SELECT 
ACCOUNT_ID,
'Account shows rapid inflow and outflow pattern with ' 
|| TOTAL_TXNS || ' transactions totaling INR '
|| TOTAL_AMOUNT || 
'. Multiple devices detected (' || DEVICE_COUNT || 
') and high counterparty count (' || UNIQUE_COUNTERPARTIES || ').'
AS SAR_NARRATIVE
FROM SAR_REPORTS
WHERE REPORT_STATUS = 'PENDING';

COPY INTO @MULE/sar_export.csv
FROM SAR_REPORTS
FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY='"');

select * from TRANSACTIONS where 
