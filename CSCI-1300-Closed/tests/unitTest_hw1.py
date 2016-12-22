import unittest
import importlib
from os import walk

identity=0;

class unitTest_identity(unittest.TestCase):
  """testing identity"""
  

  def test_identity(self):
    self.assertEquals(4,identity.identity(4),"Identity of 4")
    self.assertEquals("Hello",identity.identity("Hello"),"Identity of: Hello")

def main():
  path = "hw1/"
  f = []
  for (dirpath, dirnames, filenames) in walk(path):
    f.extend(filenames)
    break
  for file in f:
    if file.endswith(".py"):
      global identity
      identity = importlib.import_module(file[:-3],path)
      unittest.main()

if __name__ == '__main__':
    main()
