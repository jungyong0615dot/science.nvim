"""
Stream ipython output to buffer
"""

import datetime
import os
import re
import sys
import time
import uuid
from io import StringIO
from pathlib import Path
import pandas as pd

from IPython.core import magic_arguments
from IPython.core.displayhook import CapturingDisplayHook
from IPython.core.displaypub import CapturingDisplayPublisher
from IPython.core.getipython import get_ipython
from IPython.core.magic import Magics, cell_magic, magics_class
from IPython.utils.capture import CapturedIO
from pynvim import attach
from utils import summary

chunks = []

if 'tmux' in os.getenv("TMUX", '') or 'kitty' in os.getenv("TERM", ''):
  import matplotlib
  TOOL = 'matplotlib'
  RUN_ENV = 'terminal'
else:
  TOOL = 'bokeh'
  RUN_ENV = 'notebook'

ansi_escape = re.compile(
    r'''
    \x1B  # ESC
    (?:   # 7-bit C1 Fe (except CSI)
        [@-Z\\-_]
    |     # or [ for CSI, followed by a control sequence
        \[
        [0-?]*  # Parameter bytes
        [ -/]*  # Intermediate bytes
        [@-~]   # Final byte
    )
''', re.VERBOSE)


def kshow(plt):
  """Save matplotlib object to file

  Args:
      plt (): matplotlib object
  """
  savepath = Path(os.getenv('NVIM_SCIENCE_OUTPUT')) / f'tmp_{str(uuid.uuid4())}.png'
  # savepath = f'/Users/jungyonglee/Jungyong/tmp/nds/ouptut/tmp_{str(uuid.uuid4())}.png'

  plt.savefig(savepath)
  print(f'![hihi]({savepath})')

def mprint(df):
  """ Pretty print for pd.dataframe in cli environment

  Args:
      df (pd.DataFrame): input dataframe

  Returns:
      None
  """
  if not isinstance(df, pd.DataFrame):
    print(df)
    return
  if RUN_ENV == "terminal":
    print(df.to_markdown())
  else:
    display(df)


class NeoDSStream(StringIO):

  def __init__(self, initial_value='', newline='\n', stream=None, fio=None, vim=None, notifier_id=None):
    self.stream = stream
    self.fio = fio
    self.vim = vim
    self.notifier_id = notifier_id
    self.show_notify = ''
    super().__init__(initial_value, newline)

  def write(self, data):
    if self.stream is not None:
      self.stream.write(data)
      plain_data = ansi_escape.sub('', data).replace('\r', '\n')
      self.fio.write(plain_data)
      self.fio.flush()
      chunks.append(data)
      self.show_notify = self.show_notify + plain_data
      self.vim.exec_lua(f"""
local nprint = [[
{summary(self.show_notify, mode='tail')}
]]
notifiers['{self.notifier_id}'] = require('notify')(nprint, 'warn', {{title='processing', timeout = 300000, replace=notifiers['{self.notifier_id}']}})
      """)

    super().write(data)


class NeoDSCaptureOutput():
  stdout = True
  stderr = True
  display = True

  def __init__(self, stdout=True, stderr=True, display=True, buf='', vim=None, notifier_id=None):
    self.stdout = stdout
    self.stderr = stderr
    self.display = display
    self.shell = None
    self.fio = open(buf, "a")
    self.vim = vim
    self.notifier_id = notifier_id
    # self.fio = None

  def __enter__(self):

    self.sys_stdout = sys.stdout
    self.sys_stderr = sys.stderr

    if self.display:
      self.shell = get_ipython()
      if self.shell is None:
        self.save_display_pub = None
        self.display = False

    stdout = stderr = outputs = None
    if self.stdout:
      stdout = sys.stdout = NeoDSStream(stream=sys.stdout, fio=self.fio, vim=self.vim, notifier_id=self.notifier_id)
    if self.stderr:
      stderr = sys.stderr = NeoDSStream(stream=sys.stderr, fio=self.fio, vim=self.vim, notifier_id=self.notifier_id)
    if self.display:
      self.save_display_pub = self.shell.display_pub
      self.shell.display_pub = CapturingDisplayPublisher()
      outputs = self.shell.display_pub.outputs
      self.save_display_hook = sys.displayhook
      sys.displayhook = CapturingDisplayHook(shell=self.shell, outputs=outputs)
    return CapturedIO(stdout, stderr, outputs)

  def __exit__(self, exc_type, exc_value, traceback):
    sys.stdout = self.sys_stdout
    sys.stderr = self.sys_stderr
    self.fio.close()
    if self.display and self.shell:
      self.shell.display_pub = self.save_display_pub
      sys.displayhook = self.save_display_hook


@magics_class
class DsMagic(Magics):

  @magic_arguments.magic_arguments()
  @magic_arguments.argument('output', type=str, default='', nargs='?')
  @magic_arguments.argument('--no-stderr', action='store_true')
  @magic_arguments.argument('--no-stdout', action='store_true')
  @magic_arguments.argument('--no-display', action='store_true')
  @magic_arguments.argument('--stream-buffer', default='')
  @magic_arguments.argument('--bufnr', default=None)
  @magic_arguments.argument('--vpath', default=None)
  @cell_magic
  def neods(self, line, cell):
    global chunks
    chunks = []

    args = magic_arguments.parse_argstring(self.neods, line)
    out = not args.no_stdout
    err = not args.no_stderr
    disp = not args.no_display
    buf = args.stream_buffer
    bufnr = args.bufnr
    vpath = args.vpath

    vim = attach('socket', path=vpath)

    with open(buf + "_code", 'r') as input_file:
      input_code = re.sub(chr(0), '\n', input_file.read())

    notifier_id = str(uuid.uuid4()).replace("-", "")

    vim.exec_lua(f"""
local nprint = [[
{summary(input_code.strip())}
]]
notifiers = {{}}
notifiers['{notifier_id}'] = require('notify')(nprint, 'warn', {{title='started : code', timeout = 300000}})
    """)

    if '<!--markdown-->' in input_code:
      showcell = re.findall(r'"""\n<!--markdown-->((.|\n)*)"""', input_code)[0][0]
      md_cell = f"""
---------------------------------------------------------------------------
{showcell.strip()}

"""
    else:
      md_cell = f"""
---------------------------------------------------------------------------
```python
{input_code.strip()}
```
##########################################################################
###### Output[{self.shell.execution_count}]:
"""
    with open(buf, "a") as fio:
      fio.write(md_cell)

    start = time.time()

    with NeoDSCaptureOutput(out, err, disp, buf, vim, notifier_id) as iostream:
      result = self.shell.run_cell(input_code)
    if args.output:
      self.shell.user_ns[args.output] = iostream

    elapsed = time.time() - start

    # captured_out = ansi_escape.sub('',str(iostream.stdout))
    captured_out = ansi_escape.sub('', ''.join(chunks)).replace('\r', '\n')

    # vim.command("e")
    # vim.command("G")

    if result.error_before_exec or result.error_in_exec:
      title = 'Error!'
      state = 'error'
      content = result.error_before_exec or result.error_in_exec
    else:
      title = 'Done'
      state = 'info'
      # content = summary(captured_out.strip())

      # content = summary(str(iostream).strip())
      content = str(iostream).strip()

    with open(buf, "a") as fio:
      fio.write(f"\n<!-- {datetime.datetime.utcnow()}, Elapsed: {elapsed}, filename: TODO -->\n")

    vim.exec_lua(f"""
local nprint = [[
{content}
]]
local tmo = 5000
if vim.g.focused == 0 then
  tmo = 10000
end
require('notify')(nprint, '{state}', {{title='{title} : result', replace=notifiers['{notifier_id}'], timeout = tmo}})
if vim.g.focused == 0 then
  io.popen([[
  osascript -e 'display notification "Done" with title "ipython - {title}"'
  ]])
end
    """)
