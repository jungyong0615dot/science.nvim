"""
Ipython config for neods
"""
# ipython profile create neods

import os
import sys
from pathlib import Path

# import ipyparallel as ipp
import matplotlib
from IPython import get_ipython

sys.path.append(str(Path(os.getenv('NVIM_SCIENCE_SRC')) / 'python'))
from stream import DsMagic, kshow, mprint
from stream_kitty import DsMagicKitty

matplotlib.rcParams['figure.figsize'] = (12, 12)
matplotlib.rcParams['axes.labelsize'] = 20
matplotlib.rcParams['axes.titlesize'] = 20
matplotlib.rcParams['xtick.labelsize'] = 20
matplotlib.rcParams['ytick.labelsize'] = 20

get_ipython().register_magics(DsMagic)
get_ipython().register_magics(DsMagicKitty)

# get_ipython().register_magics(AsyncDsMagic)

# rc = ipp.Cluster(n=2).start_and_connect_sync()
# with rc[:].sync_imports():
#   import sys
#
#   import matplotlib
#   import nest_asyncio
#   from IPython import get_ipython
#   from pynvim import attach
#   from stream_async import AsyncDsMagic
#
#
# def initialize_clusters():
#   nest_asyncio.apply()
#   sys.path.append(str(Path(os.getenv('NVIM_SCIENCE_SRC')) / 'python'))
#   from stream import DsMagic, kshow
#   get_ipython().register_magics(AsyncDsMagic)

# rc[:].apply_sync(initialize_clusters)


#   def mprint(obj):
#     vpath = NEODS_ASYNC_VPATH
#     vim = attach('socket', path=vpath)
#     content = str(obj)
#     vim.exec_lua(f"""
# local nprint = [[
# {content}
# ]]
# require('notify')(nprint, 'warn', {{title='mprint'}})
#     """)


