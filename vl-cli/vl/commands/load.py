from sqlalchemy import types
from .command import Command
import functools as ft
import pandas
import time
import os


class Load(Command):

    def execute(self):
        if self.load_from_repo:
            return self.load_from_repository()
        else:
            return self.load_file()

    
    def load_from_repository(self):
        msg_no_envvar = 'No environment variable for VL_XLSX_LOAD_PATH'
        msg_no_file = 'No excel files found in "%s"'
        path = os.getenv('VL_XLSX_LOAD_PATH')

        if not path:
            exit(msg_no_envvar)
        try:
            files = [os.path.join(path, f) for f in os.listdir(path)
                     if f.endswith('xlsx')]
        except FileNotFoundError as e:
            exit(e)

        files = sorted(files, key=os.path.getmtime, reverse=True)
        if not files:
            exit(msg_no_file % path)
        xlfile = files[0]

        return self.load_file(xlfile)


    def load_file(self, file_name=None):
        msg_no_file = '\nNo file found'
        msg_loading = '\nLoading file to DB...'
        msg_exporting = '\nExporting excel file...'
        msg_exported = '\nFile exported! Table name is %s'

        fname = self.file_name
        table_name = self.table_name
        join_on = self.join_on
        export_file = self.export_file
        sheet = self.sheet
        drop_dup = self.drop_dup
        self.engine.echo = True

        if not file_name:
            if fname:
                file_name = fname
            else:
                exit(msg_no_file)
        base_name = os.path.basename(file_name)
        if not table_name:
            table_name = base_name.lower().replace('.xlsx', '')
        df, dtyp = self.make_df(file_name, sheet, join_on, drop_dup)
        time.sleep(5)
        try:
            if export_file:
                print(msg_exporting)
                df.to_excel(table_name + '.xlsx', index=False, encoding='utf-8',
                    freeze_panes=(1,1))
            else:
                print(msg_loading)
                df.to_sql(table_name, self.engine, index=False, if_exists=self.if_exists,
                    dtype=dtyp, chunksize=20000)
                print(msg_exported % table_name.upper())
        except Exception as e:
            exit(e)


    def make_df(self, file_name, sheet, join_on, drop_dup=True):
        msg_df_info = '\nDATAFRAME INFO: '
        msg_date_err = '\nDATE ERR: '
        msg_drop_dups = '\nDropped duplicates: %s' \
                        '\nCurrent row count: %s'
        msg_create_df = '\nCreating data frame for %s...'

        base_name = os.path.basename(file_name)
        if sheet.lower() == 'all':
            sheet = None
        else:
            sheet = sheet.split(',')
            try :
                sheet = list(map(int, sheet))
            except Exception:
                pass

        try:
            print(msg_create_df % base_name.upper())
            df = pandas.read_excel(file_name, sheet_name=sheet, dtype=object)
            if self.dont_clean:
                dfl = df
            else:
                dfl = [self.clean_df(df) for df in df.values()]
            if (not sheet or len(sheet) > 1):
                if join_on:
                    join_on = [j.replace(' ', '_').upper() for j in join_on]
                    df = ft.reduce(lambda left,right: pandas.merge(left,right, on=join_on,
                        how='outer'), dfl)
                else:
                    df = pandas.concat(dfl, sort=False)
            else:
                df = pandas.concat(dfl, sort=False)
        except Exception as e:
            exit(e)

        dtyp = {}
        df = df.fillna('').astype(str)
        for col in df.columns.tolist():
            if 'DATE' in col:
                try:
                    df[col] = df[col].astype('datetime64')
                except Exception as e:
                    print(msg_date_err, str(e))
            elif 'CLOB' in col:
                dtyp[col] = types.CLOB
            elif (df[col] == '').all():
                if ('DESCRIPTION' or 'PATH') in col:
                    dtyp[col] = types.VARCHAR(555)
                else:
                    dtyp[col] = types.VARCHAR(55)
            else:
                dtyp[col] = types.VARCHAR(df[col].map(len).max() + 5)
        print(msg_df_info)
        df.info()

        if drop_dup:
            cnt_before = len(df)
            df.drop_duplicates(inplace=True)
            cnt_after = len(df)
            print(msg_drop_dups % (str(cnt_before - cnt_after), cnt_after))

        return df, dtyp


    def clean_df(self, df):
        new_cols = [c.strip().upper().replace(' ', '_') for c in df.columns
                    .tolist()]
        df.columns = new_cols
        df = df.fillna('').astype(str)

        def fix_status(status):
            sta_to_upper = [
                'active', 'legacy', 'inactive', 'stop', 'mfg', 'eng'
            ]
            if status.lower() in sta_to_upper:
                return status.upper()
            else:
                return status.title()

        for col in df.columns.tolist():
            if 'PUID' in col:
                pass
            elif 'ID' in col:
                df[col] = df[col].str.strip()
                df[col] = df[col].str.upper()
            elif ('STATUS' or 'LIFECYCLE') in col:
                df[col] = df[col].str.strip().apply(fix_status)

        return df
