import unittest
import importlib
from os import walk

stuff=0

class unitTest_stuff(unittest.TestCase):
  """testing stuff"""
  
  def test_stuff(self):
    self.assertEquals(9,stuff.forFun(4,5),"Stuff For Fun")
    self.assertEquals(10,stuff.forWork(4,5),"Stuff For Work")

def main():
  path = "hw3/"
  f = []
  for (dirpath, dirnames, filenames) in walk(path):
    f.extend(filenames)
    break
  for file in f:
    if file.endswith(".py"):
      global stuff 
      stuff = importlib.import_module(file[:-3],path)
      unittest.main()

if __name__ == '__main__':
  main()
