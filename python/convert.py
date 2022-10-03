import argparse, json, os, re
import json

def script_to_nb(input_filename, output_filename):

  with open(input_filename, 'r') as fio:
    input_file = fio.read()

  py_str = re.sub(r"^\s+", "", input_file)
  py_str = re.sub(r"\s+$", "", input_file)

  cells = []
  chunks = re.split(rf".*{re.escape('# %%')}.*", py_str)

  for chunk in chunks:
    chunk = re.sub(r"^\n+", "", chunk)
    chunk = re.sub(r"\n+$", "", chunk)
    if '<!--markdown-->' in chunk:
      chunk = re.findall(r'"""\n<!--markdown-->((.|\n)*)"""', chunk)[0][0]
      cell_type = "markdown"
    else:
      cell_type = "code"

    cell = {
      "cell_type": cell_type,
      "metadata": {},
      "source": chunk.splitlines(True),
    }

    cells.append(cell)


  cells = [cell for cell in cells if cell["source"]]


  language="python"

  nb = {
    "cells": cells,
    "metadata": {
      "anaconda-cloud": {},
      "kernelspec": {
        "display_name": language,
        "language": language,
        "name": 'python3',
      },
    },
    "nbformat": 4,
    "nbformat_minor": 4,
  }


  with open(output_filename, "w+") as f:
    json.dump(nb, f, indent=2)

  return

if __name__ == "__main__":

  parser = argparse.ArgumentParser()
  parser.add_argument("--input", type=str, help="input file to convert")
  parser.add_argument("--output", type=str, help="output file to convert")

  args = parser.parse_args()
  script_to_nb(args.input, args.output)
