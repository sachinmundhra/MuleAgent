CREATE OR REPLACE ALERT fraud_alert
  WAREHOUSE = ACME_WH
  SCHEDULE = '5 MINUTE'
  IF (
      EXISTS (
          SELECT 1
          FROM MULE_RISK_SCORES
          WHERE RISK_LABEL like 'MULE%'
      )
     )
  THEN
  BEGIN
      CALL SYSTEM$SEND_EMAIL(
          'email_int',
          'sachin.mundhra@opustechglobal.com',
          'Fraud Alert Triggered',
          'High-risk transactions detected in TRANSACTIONS table.'
      );
  END;
