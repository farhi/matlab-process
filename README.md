# matlab-process
A Matlab class to control external processes asynchronously. 

It can be used to control a process launched from Matlab, or to monitor an other process launched independently. When the process is lauched from matlab, its standard output, and error are collected.
 
Usage
=====
 
  The syntax to launch a process is simply
  
  ```matlab
    pid = process('command arguments ...')
  ```
  
  The process class replaces the 'system' command. but is started asynchronously.
  Matlab does not wait for the end of the process to get back to interactive mode.
  The stdout and stderr are collected periodically. You can send messages 
  via the stdin channel (for interactive processes).
 
  You can as well monitor an existing external process by connecting to its PID (number)
  ```matlab
    pid = process(1234);
    pid = connect(process, 1234);
  ```
  
  or by connecting to a running named process:
  ```matlab
    pid = connect(process, 'ping');
  ```
  
  You can customize the process with e.g. additional arguments such as:
  - process(..., 'TimeOut', value)  set a TimeOut (to kill process after)
  - process(..., 'Period', value)   set the refresh rate in seconds (10 s).
  - process(..., 'Monitor', 0 or 1) flag to set the process in silent/verbose mode
  - process(..., 'TimerFcn', @fcn)  execute periodically on refresh
  - process(..., 'StopFcn', @fcn)   execute when the process is killed (stop/exit)
  - process(..., 'EndFcn', @fcn)    execute when the process ends by itself
 
  The TimerFcn, StopFcn and EndFcn can be given as:
    - simple strings, such as ```'disp(''OK'')'```
    - a function handle with none to 2 arguments. The Callback will then 
      pass as 1st argument the process object, and as 2nd the event
        in 'kill','timeout','end', or 'refresh'. 
      Example ```@(p,e)disp([ 'process ' p.Name ': event ' e ])```
    - the name of a function which takes none to 2 arguments. Same as above.
    
  When a callback has a non-zero return value, it stops the process.
 
  For instance:
  - to stop a process when a file appears, use:
      ```process(..., 'TimerFcn', @(p,e)~isempty(dir('/path/file')) )```
  - to stop a process when a file disappears, use:
      ```process(..., 'TimerFcn', @(p,e)isempty(dir('/path/file')) )```
 
  methods to monitor Processes
  - disp(pid)     display full process information.
  - pid           display short process information. Same as display(pid).
  - stdout(pid)   get the stdout stream from the process (normal output).
  - stderr(pid)   get the stderr stream from the process (errors).
  - write(pid, 'string') sends the given string to the process.
  - isreal(pid)   check if a process is valid/running.
  - refresh(pid)  force the pid to be refreshed, i.e check if it is running
                  and get its stdout/stderr.
  - silent(pid)   set the process to silent mode (do not print stdout/stderr).
  - verbose(pid)  set the process to verbose mode (print stdout/stderr).
  - etime(pid)    return the process duration since start.
  - findall(pid)  get all running process objects.
 
  methods to control execution
  - waitfor(pid)  wait for the process to end normally or on TimeOut.
  - exit(pid)     kill the process (stop it). Same as stop(pid)
  - delete(pid)   kill the process and delete it from memory.
  - killall(pid)  kill all running process objects.
  - atexit(pid, fcn) set a callback to execute at end/stop/kill.
 
  Example:
  ```matlab
    pid=process('ping 127.0.0.1'); silent(pid);
    pause(5);
    exit(pid);
  ```
  
    Copyright: Licensed under the GPL2
               E. Farhi, <emmanuel.farhi@synchrotron-soleil.fr>, http://ifit.mccode.org


Class Details
=============

Property Summary 
----------------
- Duration        How long it took 
- EndFcn          Executed when process ends normally. 
- Name            The name of the process 
- StopFcn         Executed when process is stopped/killed. 
- TimeOut         Time [s] after which process is killed if not done. 
- TimerFcn        Executed everytime the refresh function is used. 
- UserData        User area. 
- command         The command associated to the process. creationDateCreation date (start). 
- exitValue       Exit code, only valid at end of process. 
- info            additional information from the system 
- stderr          Stores the stderr from the process. 
- stdout          Stores the stdout (yes!) from the process. 
- terminationDate End date. 

Method Summary 
--------------
-  addlistener Add listener for event.   
-  atexit      sets the Exit callback (executed at stop/kill)   
-  char        convert a process object into char string   
-  connect     connect to an existing process.   
-  copyobj     makes a deep copy of initial object   
-  delete      completely remove the process from memory.    
-  disp        display Process object (details)   
-  display     display Process object (from command line)   
-  eq== (EQ)   Test handle equality.   
-  error       return the standard error stream (stderr)   
-  etime       return the process duration since start.   
-  exit        end/kill a running process and/or return its exit value.   
-  findall     find all process objects   
-  findobj     Find objects matching specified conditions.   
-  findprop    Find property of MATLAB handle object.   
-  ge>= (GE)   Greater than or equal relation for handles.   
-  gt> (GT)    Greater than relation for handles.   
-  isreal      return 1 when the process is running, 0 otherwise. Sealed   
-  isvalid     Test handle validity.   
-  kill        stop a running process   
-  killall     find all process objects   
-  le<= (LE)   Less than or equal relation for handles.   
-  lt< (LT)    Less than relation for handles.   
-  ne~= (NE)   Not equal relation for handles.   
-  notify      Notify listeners of event.   
-  read        return the standard output stream (stdout)   
-  refresh     poke a process and update its stdout/stderr.   
-  silent      set the process to silent mode.   
-  start       make sure the process onitoring is running   
-  stop        stop a running process   
-  verbose     set the process to verbose mode, which displays its stdout.   
-  waitfor     wait for the process to end normally or on TimeOut.   
-  write       send a string to the standard input stream (stdin) 

