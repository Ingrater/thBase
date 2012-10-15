thBase
======

my GC free standard library for the D 2.0 programming language

 * This currently only works with dmd 2.060 on windows
 * You will need visual studio 2008 or 2010 and VisualD 0.3.34 ( http://www.dsource.org/projects/visuald ) to compile it.
 * You will need my modified versions of druntime and phobos to compile and use this. They are also on my github account
 * Make a copy of your dmd2\windows\bin folder to dmd2\windows\bin-nostd
 * Copy the sc.ini from thBase into the just created dmd2\windows\bin-nostd folder. 
 
The folder structure should look as follows:

 * SomeGroupFolder
	* druntime
	* phobos
	* thBase

To use the library you have to specifiy the include path for my modified version of phobos and druntime with:

-I[path to druntime]\import -I[path to phobos]\phobos; -I[path to thBase]\src

Also you need to specify -version=NOGCSAFE. And link against druntime\lib\gcstub.obj (just add it to the command line).

And of course link against thBase.lib (for release) or thBased.lib (for debug)