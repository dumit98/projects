import datetime
from sqlalchemy import create_engine
#  from cx_Oracle import Connection, Cursor


class Command:
    def __init__(self, **kwargs):
        for key,val in kwargs.items():
            setattr(self, key, val)

    def __enter__(self):
        print("Connecting... ")

        self.engine = create_engine(
            'oracle+cx_oracle://cdmuser:C3tDa7aUs3R@tcinfodb.nov.com/cdm',
            connect_args={'encoding': 'utf8', 'nencoding': 'utf8'},
            max_identifier_length=128,
            echo=False)

        if hasattr(self, 'linked_server'):
            print('Site: ', self.linked_server.upper(), '\n')

    def __exit__(self, type, value, traceback):
        print("Closing Connection... ")
        # self.cur.close()
        # self.con.close()
