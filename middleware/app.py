from fastapi import FastAPI
import psycopg2
import os
import time

app = FastAPI()

def get_db_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "backend"),
        database=os.environ.get("DB_NAME", "testdb"),
        user=os.environ.get("DB_USER", "postgres"),
        password=os.environ.get("DB_PASS", "postgres")
    )

@app.get("/api/data")
def read_data():
    start_time = time.time()
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT message FROM test_data LIMIT 1;')
        db_message = cur.fetchone()[0]
        cur.close()
        conn.close()
        success = True
    except Exception as e:
        db_message = str(e)
        success = False
    
    execution_time = (time.time() - start_time) * 1000
    
    return {
        "status": "success" if success else "error",
        "data": db_message,
        "db_execution_time_ms": round(execution_time, 2)
    }
