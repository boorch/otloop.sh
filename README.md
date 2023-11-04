# otloop.sh
A macOS bash script that can set the loop start of an "ot" file based on a specific slice's startpoint and length. When modifying an ot file, a backup of the original file is created with the extension of "bak". There's also "restore" functionality that can revert your changes. The script can perform operations in all subfolders recursively by finding all ot/bak files and operating on them if required.

## Please make sure to create your own backups before using the script. I can't be held responsible for any data loss you may experience.

Remember to make otloop.sh exetucable: chmod +x otloop.sh
You can also consider placing it in [PATH](https://en.wikipedia.org/wiki/PATH_(variable)) so it's always reachable.


### Usage
       otloop.sh [-r] [-a] [filename or folder path] [slice_number]
       
       -r: restore from backup if a backup file exists
       -a: operate on all .ot or .bak files in the specified folder recursively. Requires a folder path instead of a filename       
       filename: the filename of the .ot file to modify
       slice_number: the slice number to use for the loop start and loop length
       
       Example usage for single file:  otloop.sh -r my_file.ot 2
       Example usage for all files in a folder and subfolders, starting from current folder:  otloop.sh -a . 2
       Example usage for all files in a folder and subfolders, starting from a specific folder:  otloop.sh -a my_folder 2
       
       Example usage for restoring a single file:  otloop.sh -r my_file.ot
       Example usage for restoring all files in a folder and subfolders, starting from current folder:  otloop.sh -r -a .
       Example usage for restoring all files in a folder and subfolders, starting from a specific folder:  otloop.sh -r -a my_folder


