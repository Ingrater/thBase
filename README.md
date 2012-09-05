thBase
======

my GC free standard library for the D 2.0 programming language

This currently only works with dmd 2.058 on windows
You will need visual studio 2008 or 2010 and VisualD to compile it.
You will need my modified versions of druntime and phobos to compile and use this. They are also on my github account
Modifiy the paths in the sc.ini to the paths where you checked out my versions druntime and phobos and copy it to dmd2/windows/bin. (Make a backup copy, it will break other projects)
You also need to modify the paths in th project settings.

To use the library you have to specifiy the include path for my modified version of phobos and druntime with:

-I[path to druntime]\import -I[path to phobos]\phobos; -I[path to thBase]\src

Also you need to specify -version=NOGCSAFE. And link against gcstub.obj (just add it to the command line).

And of course link against thBase.lib or thBased.lib (for debug)