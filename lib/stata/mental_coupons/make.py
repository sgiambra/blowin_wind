#! /usr/bin/env python
#****************************************************
# GET LIBRARY
#****************************************************
import subprocess, shutil, os
gslab_make_path = os.getenv('local_make_path')
subprocess.call('svn export --force -r 479 ' + gslab_make_path + ' gslab_make', shell = True)
from gslab_make.py.get_externals import *
from gslab_make.py.make_log import *
from gslab_make.py.make_links import *
from gslab_make.py.make_link_logs import *
from gslab_make.py.run_program import *
from gslab_make.py.dir_mod import *

#****************************************************
# MAKE.PY STARTS
#****************************************************
set_option(makelog = 'log/make.log', output_dir = 'log', temp_dir = '')

clear_dirs('log/')
delete_files('test/temp/*')
start_make_logging()

# RUN TEST
run_stata(program = 'test/test_deseasonalize.do')
run_rbatch(program = 'test/test_deseasonalize.R')

end_make_logging()

shutil.rmtree('gslab_make')
raw_input('\n Press <Enter> to exit.')

