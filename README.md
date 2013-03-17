thBase
======

my GC free standard library for the D 2.0 programming language

 * This currently only works with dmd 2.063 and gdc 2.060 on windows
 * You will need visual studio 2008 or 2010 and VisualD 0.3.34 ( http://www.dsource.org/projects/visuald ) to compile it.
 * You will need my modified versions of druntime and phobos to compile and use this. They are also on my github account
 * Make a copy of your dmd2\windows\bin folder to dmd2\windows\bin-nostd
 * Copy the sc.ini from thBase into the just created dmd2\windows\bin-nostd folder. 
 
The folder structure should look as follows:

 * SomeGroupFolder
	* druntime
	* phobos
	* thBase
	
To check if you set up everythign correctly up to this point you can run the "Debug" target on the thBase project inside the common.sln or common2010.sln

To use the library in one of your projects you have to specifiy the include path for my modified version of phobos and druntime with:

-I[path to druntime]\import -I[path to phobos]\phobos; -I[path to thBase]\src

Additionally for gdc you need to specify:
-nostdinc

Then you need to link against the modified version of druntime/phobos with

-defaultlib=RELEASE_LIB -debuglib=DEBUG_LIB

possible values for RELEASE_LIB are
dmd x86: phobosnogc.lib
dmd x64: phobosnogc64.lib
gdc x64: phobosnogc64_mingw

possible values for DEBUG_LIB are:
dmd x86: phobosnogcd.lib
dmd x64: phobosnogc64d.lib
gdc x64: phobosnogc64d_mingw

Also you need to specify -version=NOGCSAFE.

And of course link against the correct thBase library:
Release:
dmd x86: thBase.lib
dmd x64: thBase64.lib
gdc x64: thBase64_mingw

Debug:
dmd x86: thBased.lib
dmd x64: thBase64d.lib
gdc x64: thBase64d_mingw