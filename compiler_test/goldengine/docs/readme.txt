GOLD Engine for DigitalMars D
=============================

Author: Matthias Piepkorn
Version: 1.0
Language: DigitalMars D

Features:
- Full Unicode support, can load UTF8/16/32 files
- Event based
- Generated code is kept to a minimum
- Compatible with both Phobos and Tango
- Very fast


This engine is based on the official engine pseudocode, with some inspiration 
from the Delphi engine. It can load grammars from external files, or from 
binary arrays embedded into the code by bintod.

The parser itself will not generate a parse tree, instead the parse tree 
generation is left to the programmer.

The engine works with both standard libraries, Phobos and Tango.


Using bintod to integrate grammar files into the program
- Get it at http://www.dprogramming.com/bintod.php
- Run: bintod Grammar.cgt Grammar.d
  A file Grammar.d will be generated, which is about 4 times the size of
  your grammar
- Add Grammar.d to your project (you may need to fix module names)
- Add the line
  import Grammar.d
  to the generated class template
- In the method loadGrammar(), comment the line loading the cgt file,
  and uncomment the MemoryStream/MemoryConduit code
- Change the array name to match the array inside Grammar.d


Code templates:
- D - Constants.pgt
  This will generate a set of anonymous enums containing symbol and rule
  constants
- D - Piepkorn Engine (Separate constants).pgt
  Creates a skeleton class that will load a grammar, provide a method to
  create an object for a reduced rule, and return the parse tree root.
  Dependencies: GOLD Engine, D - Constants.pgt
- D - Piepkorn Engine (Single file).pgt
  Same as above, however the needed constants are defined in the class file
  Dependencies: GOLD Engine
