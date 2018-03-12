#! /usr/bin/env python
#****************************************************
# GET LIBRARY
#****************************************************
import subprocess, shutil, os
from gslab_make.dir_mod import *
from gslab_make.get_externals import *
from gslab_make.make_log import *
from gslab_make.make_links import *
from gslab_make.make_link_logs import *
from gslab_make.run_program import *

#****************************************************
# MAKE.PY STARTS
#****************************************************
set_option(link_logs_dir = '../output')
clear_dirs('../output', '../temp')
start_make_logging()

from gslab_fill.tablefill import tablefill
from gslab_fill.textfill import textfill

tablefill(
  input = ('../../analysis/descriptive_regressions/output/tables.txt '
           '../../analysis/covariates_balance/output/tables.txt'),
  template = './breakfast.lyx',
  output = '../output/breakfast_filled.lyx'
  )

# COMPILE (ORDER MATTERS)
run_lyx(program = '../output/breakfast_filled')

os.rename('../output/breakfast_filled.pdf', '../output/breakfast.pdf')

end_make_logging()

raw_input('\n Press <Enter> to exit.')
