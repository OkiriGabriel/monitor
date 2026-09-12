# RDS MySQL Connection Timeout Configuration

## ✅ 1. Set wait_timeout and interactive_timeout (Best for RDS)

These are allowed parameters in the RDS parameter group, and they automatically close idle connections.

### Steps in AWS RDS Console:

1. Go to **RDS → Parameter groups**
2. Choose your MySQL parameter group (or create a new one)
3. Set the following:
   - `wait_timeout = 300`
   - `interactive_timeout = 300`
   - (300 seconds = 5 minutes — adjust as needed.)
4. Apply to the DB instance
5. Reboot the instance (if required)

This is the recommended AWS method.

### Not allowed in RDS

You **cannot**:
- Kill OS-level processes
- Edit `my.cnf` directly
- Write global cron jobs

So we use allowed MySQL parameters only.

---

## 2. Identify idle sessions in RDS (optional)

### Run:

```sql
SELECT ID, USER, HOST, TIME, STATE, COMMAND
FROM information_schema.PROCESSLIST
WHERE COMMAND = 'Sleep'
ORDER BY TIME DESC;
```

### Kill manually if needed:

```sql
KILL <process_id>;
```

---

## 3. Automatically Kill Idle Sessions

### Method 1: Using wait_timeout (Automatic - Recommended)

`wait_timeout` and `interactive_timeout` automatically close idle connections after the specified time. This is the **easiest and most reliable method**.

**Limitation**: `wait_timeout` will **NOT** kill sessions that are in a transaction (e.g., `START TRANSACTION;` left open).

### Method 2: AWS Lambda + EventBridge (For Stuck Transactions)

Since RDS doesn't allow MySQL Events, use AWS Lambda to run scheduled KILL queries.

#### Step 1: Create a Stored Procedure

```sql
DELIMITER $$

CREATE PROCEDURE kill_idle_connections(
    IN max_idle_seconds INT,
    IN exclude_users TEXT
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE process_id INT;
    DECLARE cur CURSOR FOR 
        SELECT ID 
        FROM information_schema.PROCESSLIST
        WHERE COMMAND = 'Sleep'
          AND TIME > max_idle_seconds
          AND USER NOT IN (SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(exclude_users, ',', numbers.n), ',', -1)) 
                           FROM (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) numbers
                           WHERE CHAR_LENGTH(exclude_users) - CHAR_LENGTH(REPLACE(exclude_users, ',', '')) >= numbers.n - 1)
          AND ID != CONNECTION_ID(); -- Don't kill current connection
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cur;
    
    read_loop: LOOP
        FETCH cur INTO process_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        SET @kill_query = CONCAT('KILL ', process_id);
        PREPARE stmt FROM @kill_query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    
    CLOSE cur;
END$$

DELIMITER ;
```

#### Step 2: Create AWS Lambda Function (Python)

```python
import pymysql
import os
import json

def lambda_handler(event, context):
    # RDS connection details
    rds_host = os.environ['RDS_HOST']
    rds_port = int(os.environ.get('RDS_PORT', 3306))
    rds_user = os.environ['RDS_USER']
    rds_password = os.environ['RDS_PASSWORD']
    rds_database = os.environ.get('RDS_DATABASE', 'mysql')
    max_idle_seconds = int(os.environ.get('MAX_IDLE_SECONDS', 600))  # 10 minutes default
    
    try:
        # Connect to RDS
        connection = pymysql.connect(
            host=rds_host,
            port=rds_port,
            user=rds_user,
            password=rds_password,
            database=rds_database,
            connect_timeout=10
        )
        
        with connection.cursor() as cursor:
            # Call stored procedure
            cursor.callproc('kill_idle_connections', [max_idle_seconds, 'rdsadmin,root'])
            connection.commit()
            
            # Get count of killed connections
            cursor.execute("SELECT ROW_COUNT()")
            killed_count = cursor.fetchone()[0]
            
        connection.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully killed {killed_count} idle connections',
                'killed_count': killed_count
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
```

#### Step 3: Set Up EventBridge Rule

```json
{
  "Rules": [
    {
      "Name": "kill-idle-mysql-connections",
      "ScheduleExpression": "rate(5 minutes)",
      "State": "ENABLED",
      "Targets": [
        {
          "Arn": "arn:aws:lambda:region:account:function:kill-idle-connections",
          "Id": "1"
        }
      ]
    }
  ]
}
```

#### AWS CLI Commands:

```bash
# Create Lambda function
aws lambda create-function \
  --function-name kill-idle-connections \
  --runtime python3.9 \
  --role arn:aws:iam::ACCOUNT:role/lambda-rds-role \
  --handler index.lambda_handler \
  --zip-file fileb://function.zip \
  --environment Variables="{
    RDS_HOST=your-rds-endpoint.region.rds.amazonaws.com,
    RDS_USER=$RDS_USER,
    RDS_PASSWORD=$RDS_PASSWORD,
    MAX_IDLE_SECONDS=600
  }"

# Create EventBridge rule
aws events put-rule \
  --name kill-idle-mysql-connections \
  --schedule-expression "rate(5 minutes)"

# Add Lambda permission
aws lambda add-permission \
  --function-name kill-idle-connections \
  --statement-id allow-eventbridge \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:region:account:rule/kill-idle-mysql-connections

# Add Lambda as target
aws events put-targets \
  --rule kill-idle-mysql-connections \
  --targets "Id=1,Arn=arn:aws:lambda:region:account:function:kill-idle-connections"
```

### Method 3: Simple Lambda (Without Stored Procedure)

```python
import pymysql
import os

def lambda_handler(event, context):
    connection = pymysql.connect(
        host=os.environ['RDS_HOST'],
        user=os.environ['RDS_USER'],
        password=os.environ['RDS_PASSWORD'],
        database='mysql'
    )
    
    killed = 0
    with connection.cursor() as cursor:
        # Find idle connections older than 10 minutes
        cursor.execute("""
            SELECT ID 
            FROM information_schema.PROCESSLIST
            WHERE COMMAND = 'Sleep'
              AND TIME > 600
              AND USER NOT IN ('rdsadmin', 'root')
              AND ID != CONNECTION_ID()
        """)
        
        for row in cursor.fetchall():
            process_id = row[0]
            try:
                cursor.execute(f"KILL {process_id}")
                killed += 1
            except:
                pass  # Connection may have already closed
    
    connection.close()
    return {'killed': killed}
```

### Method 4: Application-Level Solution

Add connection cleanup logic in your application:

```python
# Python example
import os
import threading
import time
import mysql.connector

def cleanup_idle_connections():
    while True:
        try:
            conn = mysql.connector.connect(
                host=os.environ['RDS_HOST'],
                user=os.environ['RDS_USER'],
                password=os.environ['RDS_PASSWORD'],
                database=os.environ.get('RDS_DATABASE', 'mysql')
            )
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT CONCAT('KILL ', ID, ';')
                FROM information_schema.PROCESSLIST
                WHERE COMMAND = 'Sleep'
                  AND TIME > 600
                  AND USER NOT IN ('rdsadmin', 'root')
                  AND ID != CONNECTION_ID()
            """)
            
            for (kill_cmd,) in cursor.fetchall():
                try:
                    cursor.execute(kill_cmd)
                except:
                    pass
            
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"Error: {e}")
        
        time.sleep(300)  # Run every 5 minutes

# Start in background thread
threading.Thread(target=cleanup_idle_connections, daemon=True).start()
```

### Detect Stuck Transactions

```sql
SELECT * 
FROM information_schema.processlist
WHERE COMMAND = 'Sleep'
  AND STATE = 'Waiting for commit';
```

These require the Lambda/application-level solution since `wait_timeout` won't kill them.

---

## Recommended RDS settings

### Parameter Group Settings:

| Parameter | Recommended Value | Description |
|-----------|------------------|-------------|
| `wait_timeout` | 300 | Time in seconds before idle non-interactive connections are closed |
| `interactive_timeout` | 300 | Time in seconds before idle interactive connections are closed |

### Notes:
- Both parameters should be set to the same value for consistency
- 300 seconds (5 minutes) is a good default, but adjust based on your application needs
- These settings help prevent connection pool exhaustion
- Changes require a parameter group modification and may require a DB instance reboot

### Application-Level Best Practices:

1. **Connection Pooling**: Use connection pools with appropriate max connections
2. **Transaction Management**: Always commit or rollback transactions explicitly
3. **Connection Cleanup**: Ensure your application properly closes connections after use
4. **Monitoring**: Regularly check `information_schema.PROCESSLIST` for idle connections

---

## Quick Reference Commands

### Check current timeout settings:

```sql
SHOW VARIABLES LIKE '%timeout%';
```

### View all active connections:

```sql
SELECT * FROM information_schema.PROCESSLIST;
```

### Count connections by state:

```sql
SELECT COMMAND, STATE, COUNT(*) as count
FROM information_schema.PROCESSLIST
GROUP BY COMMAND, STATE;
```

