from sqlalchemy import create_engine, types
from sqlalchemy.exc import DatabaseError
from .db_credentials import *
from time import sleep

import pandas as pd
import logging
import cx_Oracle
import sys


class ContextFilter(logging.Filter):
    """
    This is a filter which injects contextual information into the log.
    """
    def setSite(self, site):
        self.site = site

    def filter(self, record):
        if hasattr(self, 'site'):
            site = self.site
        else:
            site = 'SITE'
        record.site = site
        return True


def tiny_etl(sql, table_name, target_db, source_db, is_plsql_block=False, if_exists='drop',
              retry=0, retry_delay=0, retry_on=[]):
    """
params
    sql            str; sql statement
    table_name     str; name of staging table name
    target_db      str; dw, ds or excel
    source_db      str or list; "all" for al prod sites or a list of sites "['houstby','edm',...]"
                   current sites are edm, fra, houstby, houprod, nor, sha, dw and ds
    is_plsql_block bool; if the sql is a plsql bock
    if_exists      str; is exist delete, drop or append
    retry          int; number of retries
    retry_delay    int; retry delay in seconds
    retry_on       list of int; oracle error code(s) to retry on, i.e. [03254, [...]]
    """

    filter = ContextFilter()
    formatter = logging.Formatter('%(asctime)s:%(levelname)s:%(name)s:[%(site)s]:%(message)s')

    if logging.root.handlers:
        handler_file = logging.root.handlers[0]
        handler_file.setFormatter(formatter)
        handler_file.addFilter(filter)

    handler_stream = logging.StreamHandler()

    log_alch = logging.getLogger('sqlalchemy.engine')
    log_alch.setLevel(logging.INFO)
    log_alch.addHandler(handler_stream)

    log_qetl = logging.getLogger(__name__)
    log_qetl.setLevel(logging.INFO)
    log_qetl.addHandler(handler_stream)

    servers = {
        'edm': edm_db_config,
        'fra': fra_db_config,
        'houstby': houstby_db_config,
        'houprod': houprod_db_config,
        'nor': nor_db_config,
        'sha': sha_db_config,
        'dw': datawarehouse_db_config,
        'ds': dataservices_db_config
    }

    if target_db.lower() == 'dw':
        eng = create_engine('oracle+cx_oracle://', connect_args=datawarehouse_db_config, echo=False)
    elif target_db.lower() == 'ds':
        eng = create_engine('oracle+cx_oracle://', connect_args=dataservices_db_config, echo=False)
    elif target_db.lower() == 'excel':
        pass
    else:
        exit('incorrect target')

    if source_db == 'all':
        selected_sites = list(servers.keys())
        selected_sites.remove('houprod')
        selected_sites.remove('dw')
        selected_sites.remove('ds')
    else:
        selected_sites = source_db

    data = []
    for site in selected_sites:

        site_upper = site.upper()
        filter.setSite(site_upper)

        log_qetl.info('{div} {site} {div}'.format(site=site_upper, div='='*30))

        if site not in servers.keys():
            log_qetl.error('%s not valid!' % site_upper)
            continue
        try:
            eng_s = create_engine('oracle+cx_oracle://', connect_args=servers[site], echo=False)

            if is_plsql_block:
                conn = eng_s.raw_connection()
                cur = conn.cursor()
                cur.execute(sql)

                res = cur.getimplicitresults()[0]
                meta = res.description
                resultset = res.fetchall()

            else:
                res = eng_s.execute(sql)
                meta = res.cursor.description
                resultset = res.fetchall()

            if resultset:
                log_qetl.info('ROWCOUNT %d' % res.rowcount)
            else:
                log_qetl.info('ROWCOUNT 0')

            df = pd.DataFrame.from_records(resultset, columns=[c[0] for c in meta])
            data.append(df)

        except DatabaseError as dberr:
            ora_err = dberr.orig.args[0].code
            ora_msg = dberr.orig.args[0].message

            if ora_err in retry_on:
                log_qetl.warning(f'retrying in {retry_delay}s for error ORA-{ora_err}')
                if retry >= 1:
                    site_index = selected_sites.index(site)
                    selected_sites.insert(site_index + 1, site)
                    sleep(retry_delay)
                    retry -= 1
            elif site == 'houstby' and 'read-only' in ora_msg:
                log_qetl.error(ora_msg)
                selected_sites.append('houprod')
            else:
                log_qetl.error(ora_msg)

            continue

    filter.setSite(target_db.upper())

    try:
        df = pd.concat(data, sort=False)
        df.drop_duplicates(inplace=True)
    except Exception as e:
        log_qetl.fatal(e)
        raise Exception(e)

    dtyp = {}
    for col in meta:
        name = col[0]
        type = col[1]
        size = col[2] if col[2] else 1

        if type == cx_Oracle.STRING:
            dtyp[name] = types.VARCHAR(size)
        elif type == cx_Oracle.FIXED_CHAR:
            dtyp[name] = types.VARCHAR(size + 5)
        elif type == cx_Oracle.NUMBER:
            dtyp[name] = types.FLOAT(size)
        elif type == cx_Oracle.DATETIME:
            dtyp[name] = types.DATE
        elif type == cx_Oracle.TIMESTAMP:
            dtyp[name] = types.TIMESTAMP

    log_qetl.info('{div} {site} {div}'.format(site=target_db.upper(), div='='*30))
    log_qetl.info('META')
    log_qetl.info(meta)
    # print('\n'.join(meta))

    if target_db == 'excel':
        with pd.ExcelWriter(table_name) as writer:
            df.to_excel(writer, index=False, sheet_name='Sheet1', freeze_panes=(1, 0))
            writer.book.create_sheet('Sheet2')
            writer.book.worksheets[1]['A2'] = sql
    else:
        if if_exists == 'delete':
            eng.connect().execution_options(autocommit=True).execute(f'DELETE {table_name.lower()}')
            if_exists = 'append'
        elif if_exists == 'drop':
            if_exists = 'replace'
        elif if_exists == 'append':
            pass
        else:
            raise Exception(f'if_exist expecting "delete", "drop" or "append", got ({if_exists})')

        # if not df.empty:
        df.to_sql(table_name.lower(), eng, if_exists=if_exists, index=False, dtype=dtyp,
                    chunksize=20000)
