from .query_executer import QueryExecuter
from .command import Command


class Input(Command):

    def execute(self):
        self.show_summary = False
        self.fname = 'input_util' if self.input_utility else 'input_bulk'
        self.outfile = 'txt' if self.input_utility else 'excel'

        return QueryExecuter(**self.__dict__).execute()
