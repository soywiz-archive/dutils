@echo off
SET FILES=
SET FILES=%FILES% test.d
SET FILES=%FILES% goldengine\dfastate.d
SET FILES=%FILES% goldengine\goldparser.d
SET FILES=%FILES% goldengine\grammar.d
SET FILES=%FILES% goldengine\lalrstate.d
SET FILES=%FILES% goldengine\rule.d
SET FILES=%FILES% goldengine\sourcereader.d
SET FILES=%FILES% goldengine\stack.d
SET FILES=%FILES% goldengine\symbol.d
SET FILES=%FILES% goldengine\token.d
SET FILES=%FILES% goldengine\unicodebom.d
dmd %FILES% -oftest.exe