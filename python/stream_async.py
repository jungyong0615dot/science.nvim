"""
Ipython output stream for ipyparallel async cell
"""

import os
import datetime
import uuid
import re
from IPython.core import magic_arguments
from IPython.core.magic import Magics, cell_magic, magics_class
from utils import summary
from pynvim import attach


@magics_class
class AsyncDsMagic(Magics):
  """ Magic for ipyparallel """

  @magic_arguments.magic_arguments()
  @magic_arguments.argument('output', type=str, default='', nargs='?')
  @magic_arguments.argument('--no-stderr', action='store_true')
  @magic_arguments.argument('--no-stdout', action='store_true')
  @magic_arguments.argument('--no-display', action='store_true')
  @magic_arguments.argument('--stream-buffer', default='')
  @magic_arguments.argument('--bufnr', default=None)
  @magic_arguments.argument('--vpath', default=None)

  @cell_magic
  def async_neods(self, line, cell):
    """ Cell magic.

    Args:
        line (): line
        cell (): cell
    """

    args = magic_arguments.parse_argstring(self.async_neods, line)
    buf = args.stream_buffer
    vpath = args.vpath

    vim = attach('socket', path=vpath)

    with open(buf + '_code', 'r', encoding='utf-8') as input_file:
      input_code = re.sub(chr(0), '\n', input_file.read())

    notifier_id = str(uuid.uuid4()).replace('-', '')

    vim.exec_lua(f"""
local nprint = [[
{summary(input_code.strip())}
]]
notifiers = {{}}
notifiers['{notifier_id}'] = require('notify')(nprint, 'warn', {{title='started : ASYNC!', timeout = 300000}})
    """)

    result = self.shell.run_cell(input_code)

    if result.error_before_exec or result.error_in_exec:
      title = 'Error!'
      state = 'error'
      content = result.error_before_exec or result.error_in_exec
    else:
      title = 'Done'
      state = 'info'
      content = 'Done'

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
    with open(buf, 'a', encoding='utf-8') as fio:
      fio.write(md_cell)
    with open(buf, 'a', encoding='utf-8') as fio:
      fio.write(f'\n<!-- {datetime.datetime.utcnow()}, Elapsed: __, filename: TODO -->\n')

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
