@echo off
SET SOURCES=
SET SOURCES=%SOURCES% string_utils.d
SET SOURCES=%SOURCES% stream_aggregator.d
SET SOURCES=%SOURCES% rangelist.d
SET SOURCES=%SOURCES% patches.d
SET SOURCES=%SOURCES% ppf.d
SET SOURCES=%SOURCES% pmips_textsearch.d
SET SOURCES=%SOURCES% pmips_pointersearch.d
SET SOURCES=%SOURCES% pmips_patcher.d
dmd %SOURCES% -run pmips.d %*