"""

"""


from pynvim import attach
from io import StringIO
import sys
import string

import re
from IPython.core import magic_arguments
from IPython.core.magic import Magics, cell_magic, magics_class
from IPython.utils.capture import CapturedIO

def string_head(input, max_line=3, max_letter=40):
  lines = input.split("\n")
  lines = [line[:max_letter] + ".." if len(line) > max_letter else line for line in lines]
  # lines = [line.replace("'", "\\\'") for line in lines]
  # lines = [re.sub("'", "\\\'", line) for line in lines]
  # lines = [line.replace('"', "'") for line in lines]
  # lines = [re.sub('"', "\\\"", line) for line in lines]

  # lines = [line[:min(len(line), max_letter)] for line in lines]
  return '\n'.join(lines[:min(len(lines), max_line)])

class NeoDSStream(StringIO):
  def __init__(self, initial_value='', newline='\n', stream=None, fio=None):
    self.stream = stream
    self.fio = fio
    super().__init__(initial_value, newline)
  
  def write(self, data):
    if self.stream is not None:
      self.stream.write(data)
      self.fio.write(data)
      self.fio.flush()
    
    super().write(data)


class NeoDSCaptureOutput(object):
  stdout = True
  stderr = True
  display = True
  
  def __init__(self, stdout=True, stderr=True, display=True, buf=''):
    self.stdout = stdout
    self.stderr = stderr
    self.display = display
    self.shell = None
    self.fio = open(buf, "a")
  
  def __enter__(self):
    from IPython.core.getipython import get_ipython
    from IPython.core.displaypub import CapturingDisplayPublisher
    from IPython.core.displayhook import CapturingDisplayHook
    
    self.sys_stdout = sys.stdout
    self.sys_stderr = sys.stderr
    
    if self.display:
      self.shell = get_ipython()
      if self.shell is None:
        self.save_display_pub = None
        self.display = False
    
    stdout = stderr = outputs = None
    if self.stdout:
      stdout = sys.stdout = NeoDSStream(stream=sys.stdout, fio=self.fio)
    if self.stderr:
      stderr = sys.stderr = NeoDSStream(stream=sys.stderr, fio=self.fio)
    if self.display:
      self.save_display_pub = self.shell.display_pub
      self.shell.display_pub = CapturingDisplayPublisher()
      outputs = self.shell.display_pub.outputs
      self.save_display_hook = sys.displayhook
      sys.displayhook = CapturingDisplayHook(shell=self.shell,
                         outputs=outputs)
    
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
    args = magic_arguments.parse_argstring(self.neods, line)
    out = not args.no_stdout
    err = not args.no_stderr
    disp = not args.no_display
    buf = args.stream_buffer
    bufnr = args.bufnr
    vpath = args.vpath

    vim = attach('socket', path=vpath)
    vim.command("lua require('notify')('started')")

    with open(buf + "_code", 'r') as input_file:
      input_code = re.sub(chr(0),'\n',input_file.read())

    with open(buf, "a") as fio:
      md_cell = f"""
---
```python
{input_code.strip()}
```

"""
      fio.write(md_cell)

    with NeoDSCaptureOutput(out, err, disp, buf) as io:
      self.shell.run_cell(input_code)
    if args.output:
      self.shell.user_ns[args.output] = io

    vim.command("e")
    vim.exec_lua(f"""
local nprint = [[
{string_head(input_code.strip())}
]]
require('notify')(nprint, 'info', {{title='Done'}})
    """)
