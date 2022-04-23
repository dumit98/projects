from .query_executer import QueryExecuter
from .command import Command

class Report(Command):

    def execute(self):
        self.fname = 'report'
        self.outfile = 'excel'

        return QueryExecuter(**self.__dict__).execute()
