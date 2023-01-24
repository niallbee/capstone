import os
import psycopg2

def db_connection():
    conn = psycopg2.connect(host=os.environ['DB_IP'],
                            database='application',
                            user=os.environ['DB_USERNAME'],
                            password=os.environ['DB_PASSWORD'])
    return conn