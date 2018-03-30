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
google_drive = 'G:/My Drive/research projects/wind/stata/build_wind_panel'

set_option(link_logs_dir = '../output')
clear_dirs('../output', '../temp', google_drive)
start_make_logging()

run_stata(program='build_wind_panel_zillow.do', executable='StataSE-64')
run_stata(program='build_wind_panel_fhfa.do', executable='StataSE-64')

end_make_logging()

raw_input('\n Press <Enter> to exit.')
