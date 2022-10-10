"""
Utils for stream
"""

def summary(input_str, mode='head', threshold_lines=5, threshold_letters=40):
  """return head of the string. Used for neovim notification

  Args:
      input_str (str): output string
      threshold_lines (): maximum number of lines
      threshold_letters (): maximum number of rows

  Returns:
      truncated string
  """
  lines = input_str.split('\n')
  lines = [line[:threshold_letters] + '..' if len(line) > threshold_letters else line for line in lines]
  return '\n'.join(lines[:min(len(lines), threshold_lines)]) if mode == 'head' else '\n'.join(
      lines[-1 * threshold_lines:])
