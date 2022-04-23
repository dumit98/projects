from tabulate import tabulate
from .command import Command
from sqlalchemy.orm.session import sessionmaker
from sqlalchemy import inspect
import pprint
import pandas as pd
import re


class Sql(Command):

    def execute(self):
        tabl = self.table_name
        stmt = self.statement

        Session = sessionmaker()
        self.sess = Session(bind=self.engine)
        conn = self.sess.connection()
        try:
            self.parse_statement(stmt)
            eval('self.{0}(conn, tabl)'.format(self.dml_type))
        except Exception as e:
            exit(e)

    
    def select(self, conn, table):
        return self.do_query(conn, table)


    def update(self, conn, table):
        sql = f'update {table} {self.statement}'
        msg = '\n{0} row(s) affected'
        q = conn.execute(sql)

        print(msg.format(q.rowcount))
        self.do_query(conn, table)
        return self.commit()


    def info(self, conn, table):
        inspector = inspect(conn)
        info = inspector.get_columns(table)

        print(tabulate(info, headers='keys', tablefmt='psql', showindex=True))


    def delete(self, conn, table):
        pass


    def alter(self, conn, table):
        pass


    def commit(self):
        while True:
            resp = input('Commit? [y/n] >> ').lower()
            if resp == 'y':
                self.sess.commit()
                break
            elif resp == 'n':
                self.sess.rollback()
                break
            else:
                continue


    def do_query(self, conn, table):
        sql = 'select {0} from {1} {2} {3}'
        stmt = self.statement
        cols = ','.join(self.cols) if self.cols else stmt
        WHERE = self.where
        GROUPBY = ''
        dml_type = self.dml_type

        #  if dml_type != 'select':
            #  if not WHERE:
                #  WHERE = 'where rownum <= 10'
        if 'distinct' in stmt:
            GROUPBY = ' group by ' + cols.replace('distinct', '')
            cols = cols + ', count(*)'
        quer = sql.format(cols, table, WHERE, GROUPBY)
        df = pd.read_sql(quer, conn)
        if not df.empty:
            if len(df.index) > 100 or len(df.columns) > 5:
                table = df
            else:
                table = tabulate(df, headers='keys', tablefmt='psql', showindex=True)

            return print('\n', table, '\n')


    def parse_statement(self, input_str):
        stmt_parts = {}
        dml_type = re.search('^\s*\w+', input_str).group().lower()
        if dml_type == 'select':
            stmt = re.search('\(.*?(?=where)', input_str)
            if not stmt:
                stmt = re.search('\(.*\)\s*$', input_str)
        else:
            stmt = re.search('\(.*\)\s*$', input_str)

        stmt = stmt.group() if stmt else exit('\nMissing "()"')
        stmt = re.sub('^\(|\)$', '', stmt)
        cols = re.findall('\w+\s*=', input_str)
        cols = [re.sub('=', '', c) for c in cols]
        where = re.search('where.*', input_str)
        if where:
            where = where.group()
            where = re.sub('^\(|\)$', '', where)
        
        stmt_parts['statement'] = stmt
        stmt_parts['cols'] = cols
        stmt_parts['where'] = where
        stmt_parts['dml_type'] = dml_type

        for key,val in stmt_parts.items():
            setattr(self, key, val)
