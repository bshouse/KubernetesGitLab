import unittest
import importlib
from os import walk

add_numbers=0

class unitTest_add_numbers(unittest.TestCase):
  """testing add_numbers"""
  
  def test_add_numbers(self):
    self.assertEquals(9,add_numbers.add_numbers(4,5),"adding 4 and 5")
    self.assertEquals(0,add_numbers.add_numbers(5,-5),"adding 5 and -5")

def main():
  path = "hw2/"
  f = []
  for (dirpath, dirnames, filenames) in walk(path):
    f.extend(filenames)
    break
  for file in f:
    if file.endswith(".py"):
      global add_numbers
      add_numbers = importlib.import_module(file[:-3],path)
      unittest.main()

if __name__ == '__main__':
  main()
