from sqlalchemy import types
from .command import Command
from .load import Load
import pandas


class Clone(Command):

    sql = """
        select * from mdmp2ptce.{0}
        where loadidentifier = '{1}'
        """
    sources = {
        'caps': 'nov_caps_item_master_list',
        'jde': 'nov_jde_item_master_list',
        'syteline': 'tbd',
        'bomload': 'nov_caps_bom_list',
        'docload': 'nov_cet_document_load',
        'docrel': 'nov_cet_part_document_relation'
    }

    def execute(self):
        msg_drop_dups = '\nDropped duplicates: %s' \
                        '\nCurrent row count: %s' \
                        '\n'
        df = pandas.read_sql(
            self.sql.format(self.sources[self.source], self.load_id), self.engine
        )

        if self.dont_clean:
            pass
        else:
            df = Load().clean_df(df)
        
        cnt_before = len(df)
        df.drop_duplicates(inplace=True)
        cnt_after = len(df)
        print(msg_drop_dups % (str(cnt_before - cnt_after), cnt_after))

        dtyp = {}
        for col in df.columns.tolist():
            if 'DATE' in col:
                try:
                    df[col] = df[col].astype('datetime64')
                except Exception as e:
                    print(msg_date_err, str(e))
            elif (df[col] == '').all():
                if ('DESCRIPTION' or 'PATH') in col:
                    dtyp[col] = types.VARCHAR(555)
                else:
                    dtyp[col] = types.VARCHAR(55)
            else:
                dtyp[col] = types.VARCHAR(df[col].map(len).max() + 5)

        self.engine.echo = True
        df.to_sql(self.table_name, self.engine, index=False, if_exists=self.if_exists,
                  dtype=dtyp, chunksize=20000)
