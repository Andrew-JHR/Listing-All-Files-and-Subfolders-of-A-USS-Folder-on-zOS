# Listing All Files and Subfolders of A USS Folder on zOS

1. This program written in Assembler is used to list all USS (UNIX System Services) files and subfolders' files of a z/OS

2. The program accepts one argument: the folder's name. If '/' is specified as the argument, it will list the entire USS system's folders and files.

3. Please refer to '___UNIX System Services Programming: Assembler Callable Services Reference___' for the APIs (e.g. BPX1OPD) called in the program.

4. The sample output of the program is '**SYS1.ZOS.D240410.OMVS.txt**'.

5. The current output record size is fixed to be 400 bytes. The length suffices in general cases. You should create a sequential data set with '**RECFM=FB**'
   and '**LRECL=400**' as the output for this program. 
   
6. If you want to increase the record size to accommodate more lengthy records, just search '**WKSIZE**' in the source code and change it from '400' to some other numbers, for example '500', but remember to allocate a different output data set's LRECL to that number accordingly.    

7. The program demonstrates how to code ***recursive*** code -- a program calls itself as a subroutine -- in Assembler.

8. The JCL statements to run the program are also included in the source file and if you want to list all the files according to the updated times and let those most recently updated files appear first, just activate the SORT step by removing the proceeding '//' cards and unmarking those JCL cards around '__DSN=&&TEMP,...__'.