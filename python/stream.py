"""
example

cell 1
from IPython import get_ipython
get_ipython().register_magics(CustomMagics)

cell 2
%%tee output
for _ in range(0,10):
  time.sleep(1)
  print(56)

"""


from io import StringIO
import sys

from IPython.core import magic_arguments
from IPython.core.magic import Magics, cell_magic, magics_class
from IPython.utils.capture import CapturedIO


class Tee(StringIO):
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


class capture_and_print_output(object):
  stdout = True
  stderr = True
  display = True
  
  def __init__(self, stdout=True, stderr=True, display=True):
    self.stdout = stdout
    self.stderr = stderr
    self.display = display
    self.shell = None
    self.fio = open("hihi.md", "a")
  
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
      stdout = sys.stdout = Tee(stream=sys.stdout, fio=self.fio)
    if self.stderr:
      stderr = sys.stderr = Tee(stream=sys.stderr, fio=self.fio)
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
class CustomMagics(Magics):
  @magic_arguments.magic_arguments()
  @magic_arguments.argument('output', type=str, default='', nargs='?')
  @magic_arguments.argument('--no-stderr', action='store_true')
  @magic_arguments.argument('--no-stdout', action='store_true')
  @magic_arguments.argument('--no-display', action='store_true')
  @cell_magic
  def tee(self, line, cell):
    with open("hihi.md", "a") as fio:
      md_cell = f"""
```python
{cell}
```
"""
      fio.write(md_cell)
    args = magic_arguments.parse_argstring(self.tee, line)
    out = not args.no_stdout
    err = not args.no_stderr
    disp = not args.no_display
    with capture_and_print_output(out, err, disp) as io:
      self.shell.run_cell(cell)
    if args.output:
      self.shell.user_ns[args.output] = io
