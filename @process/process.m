classdef process < handle
  % process(command): starts a system command
  % 
  % pid = process('command arguments ...')
  %
  % The process class replaces the 'system' command. but is started asynchronously.
  % Matlab does not wait for the end of the process to get back to interactive mode.
  % The stdout and stderr are collected periodically. You can send messages 
  % via the stdin channel (for interactive processes - see below).
  %
  % You can as well monitor an existing external process by connecting to its PID (number)
  % 
  %   pid = process(1234);
  %   pid = connect(process, 1234);
  %
  % or by connecting to a running named process:
  %
  %   pid = connect(process, 'ping');
  %
  % but you will then not be able to capture the stdout and stderr messages, nor 
  % send messages via 'write'.
  %
  % You can customize the process with e.g. additional arguments such as:
  %   process(..., 'TimeOut', value)  set a TimeOut (to kill process after)
  %   process(..., 'Period', value)   set the refresh rate in seconds (10 s).
  %   process(..., 'Monitor', 0 or 1) flag to set the process in silent/verbose mode
  %   process(..., 'TimerFcn', @fcn)  execute periodically on refresh
  %   process(..., 'StopFcn', @fcn)   execute when the process is killed (stop/exit)
  %   process(..., 'EndFcn', @fcn)    execute when the process ends by itself
  %   process(..., 'reader', 'fast')  use a fast reader for stdout/stderr, but less robust (may block)
  %
  % The TimerFcn, StopFcn and EndFcn can be given as:
  %   * simple strings, such as 'disp(''OK'')'
  %   * a function handle with none to 2 arguments. The Callback will then 
  %     pass as 1st argument the process object, and as 2nd the event
  %       in 'kill','timeout','end', or 'refresh'. 
  %     Example @(p,e)disp([ 'process ' p.Name ': event ' e ])
  %   * the name of a function which takes none to 2 arguments. Same as above.
  % When a callback has a non-zero return value, it stops the process.
  %
  % For instance:
  %   to stop a process when a file appears, use:
  %     process(..., 'TimerFcn', @(p,e)~isempty(dir('/path/file')) )
  %   to stop a process when a file disappears, use:
  %     process(..., 'TimerFcn', @(p,e)isempty(dir('/path/file')) )
  %
  % You can also monitor the process termination with:
  %   addlistener(pid, 'processEnded', @(src,evt)disp('process just end'))
  %
  % methods to monitor Processes
  %   disp(pid)     display full process information.
  %   pid           display short process information. Same as display(pid).
  %   read(pid)     get the stdout stream from the process (normal output).
  %   error(pid)    get the stderr stream from the process (errors).
  %   write(pid, 'string') sends the given string to the process.
  %   isreal(pid)   check if a process is valid/running.
  %   refresh(pid)  force the pid to be refreshed, i.e check if it is running
  %                 and get its stdout/stderr.
  %   silent(pid)   set the process to silent mode (do not print stdout/stderr).
  %   verbose(pid)  set the process to verbose mode (print stdout/stderr).
  %   etime(pid)    return the process duration since start.
  %   findall(pid)  get all existing process objects.
  %
  % methods to control execution
  %   waitfor(pid)  wait for the process to end normally or on TimeOut.
  %   exit(pid)     kill the process (stop it). Same as stop(pid)
  %   delete(pid)   kill the process and delete it from memory.
  %   killall(pid)  kill all running process objects.
  %   atexit(pid, fcn) set a callback to execute at end/stop/kill.
  %   period(pid, dt) set the monitoring period (default is 10s)
  %
  % Example:
  %   pid=process('ping 127.0.0.1'); silent(pid);
  %   pause(5);
  %   exit(pid);
  %
  %   Copyright: Licensed under the BSD
  %              E. Farhi, ILL, France <farhi@ill.fr> Aug 2012, http://ifit.mccode.org
    
  properties
    Name             = '';    % The name of the process
    command          = '';    % The command associated to the process.
    terminationDate  = [];    % End date.
    stdout           = [];    % Stores the stdout (yes!) from the process.
    stderr           = [];    % Stores the stderr from the process.
    exitValue        = '';    % Exit code, only valid at end of process.
    creationDate     = now;   % Creation date (start).
    StopFcn          = '';    % Executed when process is stopped/killed.
    EndFcn           = '';    % Executed when process ends normally.
    TimerFcn         = '';    % Executed every time the refresh function is used.
    UserData         = [];    % User area.
    TimeOut          = [];    % Time [s] after which process is killed if not done.
    Duration         = 0;     % How long it took
    info             = [];    % additional information from the system

  end
  
  properties (Access=private)
    
    % Default properties
    Runtime          = [];    % Java RunTime object
    stdinStream      = '';
    stderrStream     = '';
    stdoutStream     = '';
    timer            = [];    % the internal timer
    isActive         = 0;
    Monitor          = 1;
    PID              = [];   % for external processes (non Java)
    interactive      = true;

  end % properties
  
  events
    processStarted    % when the process starts
    processEnded      % when the process stops or is killed
    processUpdate     % when the process is updated
  end % events
  
  % --------------------------------------------------------------------------
  methods
    % the process creator (initializer)
    function pid = process(command, varargin)
      % PROCESS(command) instantiate a process object and start the command
      %
      %  p=PROCESS('command') start given command
      %  p=PROCESS(PID)       monior existing process PID
      %  p=PROCESS(process, 'name') monior existing process 'name'
      
      % should add: Display = 1 => show stdout while it comes
      if nargin == 0, command = ''; end
      
      if isa(command, 'timer') || isa(command, 'process')
        name = get(command, 'Name');
      else name = num2str(command); end
      
      pid.timer = timer( ...
          'ExecutionMode', 'fixedSpacing', ...
          'Name', name, ...
          'UserData', [], ...
          'Period', 10.0);
      pid.Name = name;
          
      % use hidden features
      try; pid.info.NumCores    = feature('NumCores'); end
      try; pid.info.GetOS       = feature('GetOS'); end
      try; pid.info.MatlabPid   = feature('GetPid'); end
      try; pid.info.NumThreads  = feature('NumThreads'); end
      pid.info.UserPath = userpath;
      pid.info.Computer = computer;
      
      % search for specific options in varargin
      index = 1;
      while index <= numel(varargin)
        this = varargin{index};
        if index < numel(varargin), val = varargin{index+1}; 
        else val = []; end
        if ischar(this)
          switch lower(this)
          case 'monitor'
            if isempty(val), val = 1; end
            if ~isempty(val) && val, pid.Monitor = val; end
          case 'silent'
            if isempty(val) , val = 0; end
            pid.Monitor = ~val;
          case {'timerfcn'}
            if ~isempty(val), pid.TimerFcn = val; end
          case {'endfcn','callback'}
            if ~isempty(val), pid.EndFcn = val; end
          case {'stopfcn','killfcn'}
            if ~isempty(val), pid.StopFcn = val; end
          case 'period'
            if ~isempty(val) && val > 0, set(pid.timer, 'Period', val); end
          case 'userdata'
            if ~isempty(val), pid.UserData = val; end
          case 'timeout'
            if ~isempty(val) && val>0, pid.TimeOut = val; end
          case {'name','tag'}
            if ~isempty(val) pid.Name = val; end
          case {'interactive','write','stdin','reader'}
            if ~isempty(val)
              if ischar(val)
                if strcmp(val, 'fast') val = false; else val = true; end
              end
              if val, pid.interactive = true; end
            end
          end
        end
        index = index+1;
      end
          
      set(pid.timer, 'TimerFcn',{@refresh_fcn, 'Refresh'}, ...
          'StopFcn', { @exit_fcn, 'Kill' }, 'UserData', pid);
      
      % start process/timer when given a command or PID
      if ischar(command) && ~isempty(command)
        % create a java object for given command to execute
        
        pid.Runtime = java.lang.Runtime.getRuntime().exec(command);
        pid.command = command;
        pid.PID     = char(pid.Runtime);
        pid.creationDate  = now;
        
        % I/O from process
        pid.stdinStream   = pid.Runtime.getInputStream; % type: java.io.InputStream (in fact stdout for process)
        pid.stderrStream  = pid.Runtime.getErrorStream; % type: java.io.InputStream (stderr)
        pid.stdoutStream  = pid.Runtime.getOutputStream;% type: java.io.OutputStream (in fact stdin for process)
        
        if pid.Monitor
          disp([ datestr(now) ': process ' pid.Name ' is starting.' ])
        end;
        start(pid);
      elseif isnumeric(command) && ~isempty(command)
        pid = connect(pid, command);  % external command given as PID
      elseif isa(command, 'timer') && isa(get(command,'UserData'),'process')
        % transfer properties
        % this is a safe way to instantiate a subclass
        pid = copyobj(get(command,'UserData'));
        start(pid);
      elseif  isa(command, 'process') 
        % transfer properties
        % this is a safe way to instantiate a subclass
        pid = copyobj(command);
        start(pid);
      elseif ~isempty(command)
        error([ mfilename ': ERROR: unsupported input argument of class ' class(command) ])
      end
    end % process
    
    % --------------------------------------------------------------------------
    function refresh(pid)
      % REFRESH poke a process and update its stdout/stderr.
      for index=1:prod(size(pid))
        if ~isvalid(pid(index)), continue; end
        refresh_Process(get_index(pid,index));
      end

    end
    
    % --------------------------------------------------------------------------
    function ex = exit(pid)
      % EXIT end/kill a running process and/or return its exit value.
      ex = [];
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if isvalid(this.timer) && any(strcmp(get(this.timer,'Running'),'on'))
          refresh_Process(this);
        end
        ex(end+1) = exit_Process(this, 'kill');
      end
      
    end
    
    % --------------------------------------------------------------------------
    function delete(pid)
      % DELETE completely remove the process from memory. 
      % The process is killed. Its stdout/err/value are lost.
      
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        exit(this);
        try
          delete(this.timer); % remove the timer
          this.timer = [];
        catch ME
          disp(ME.message)
        end
      end

    end

    % i/o methods
    function s = read(pid)
      % READ return the standard output stream (stdout)
      s = {};
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), s{end+1}=nan; continue; end
        refresh(this);
        s{end+1} = this.stdout;
      end
      if numel(s) == 1, s=s{1}; end
    end
    
    function s = error(pid)
      % ERROR return the standard error stream (stderr)
      s = {};
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), s{end+1}=nan; continue; end
        refresh(this);
        s{end+1} = this.stderr;
      end
      if numel(s) == 1, s=s{1}; end
    end
    
    function write(pid, message)
      % WRITE send a string to the standard input stream (stdin)
      if nargin < 2 || ~ischar(message), return; end
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if isvalid(this.timer) && ~isempty(this.stdoutStream) && isjava(this.Runtime)
          os = this.stdoutStream; % java.io.OutputStream (from getOutputStream)
          write(os, uint8(message));
          flush(os);
        end
      end
    end % write
    
    function s = isreal(pid)
      % ISREAL return 1 when the process is running, 0 otherwise.
      s = [];
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this) || ~isvalid(this.timer), s(end+1)=0; continue; end
        refresh(this);
        s(end+1) = this.isActive;
      end
    end
    
    function silent(pid)
      % SILENT set the process to silent mode.
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), continue; end
        this.Monitor = 0;
      end
    end
    
    function verbose(pid)
      % VERBOSE set the process to verbose mode, which displays its stdout.
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), continue; end
        this.Monitor = 1;
      end
    end
    
    function t=etime(pid)
      % ETIME return the process duration since start.
      t = [];
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if isreal(this)
          t(index)=etime(clock, datevec(this.creationDate));
        else
          t(index)=etime(datevec(this.terminationDate), datevec(this.creationDate));
        end
      end
    end % etime
    
    function dt = period(pid, dt)
      % PERIOD get or set the process monitoring period.
      %   PERIOD(pid) returns the current monitoring period. Default is 10 s.
      %
      %   PERIOD(pid, dt) sets the monitoring period [s].
      if ~isvalid(pid), dt=nan; return; end
      if nargin == 1 && isa(pid.timer, 'timer')
        dt = get(pid.timer,'Period');
      elseif isnumeric(dt) && isscalar(dt) && dt > 0
        stop(pid.timer);
        set(pid.timer,'Period',dt);
        start(pid.timer);
      end
    end % period
    
    function start(pid)
      % START make sure the process monitoring is running
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), continue; end
        start(this.timer);
        notify(this, 'processStarted');
      end
    end % start
    
    function waitfor(pid)
      % WAITFOR wait for the process to end normally or on TimeOut.
      %   Pressing Ctrl-C during the wait loop stops waiting, but does not kill the process.
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        if ~isvalid(this.timer), continue; end
        period = get(this.timer, 'Period');
        while isreal(this)
          pause(period);
        end
      end
    end
    
    function kill(obj)
      % KILL stop a running process
      stop(obj);
    end
    
    function stop(pid, action)
      % STOP stop a running process (kill)
      if nargin < 2, action='kill'; end
      for index=1:prod(size(pid))
        this = get_index(pid, index);
        if ~isvalid(this), continue; end
        stop(this.timer);
        feval(@exit_Process, this, action);
      end
    end
    
    function obj1 = connect(obj0, pid)
      % CONNECT connect to an existing process.
      %
      %  p=connect(process, PID)
      %  p=connect(process, 'name')
      obj1 = [];  % always use a new object for the connection
      if isnumeric(pid) || ischar(pid)
        [PID, command] = get_command(pid);  % can be a vector
        
        if isempty(PID)
          error([ datestr(now) ':  process PID ' num2str(pid) ' does not exist.' ])
        end

        for index=1:numel(PID)
          obj = process;  % create a new process object;
          % we have found a corresponding process. Connect to it.
          obj.Runtime = PID(index);   % PID (list of ID's)
          if iscellstr(command) && numel(command) >= index
            obj.command       = command{index};
          else
            obj.command       = pid;     % the initial request
          end
          obj.creationDate  = now;
          obj.PID           = PID(index);
          if obj.Monitor
            disp([ datestr(now) ': process ' num2str(pid) ' is connected to ' mat2str(PID(index)) ])
          end
          obj.Name = num2str(pid);
          start(obj);
          
          obj1 = [ obj1 obj ];
        end
          
      end
    end % connect
    
    function pid = findall(obj)
      % FINDALL find all process objects
      %   FINDALL(process) lists all existing process objects.
      %   To get those that are alive, use: p=FINDALL(process); isreal(p);
      
      if ~isreal(obj), obj = timerfindall; end
      pid = [];
      for index=1:prod(size(obj))
        this = obj(index);
        if ~isvalid(this), continue; end
        p = get(this, 'UserData');
        if isa(p, 'process') % this is a timer attached to a process
          pid = [ pid p ];
        end
      end
    end % findall
    
    function killall(obj)
      % KILLALL find all process objects
      pid = findall(obj);
      stop(pid);
    end % killall
    
    function atexit(obj, fcn)
      % ATEXIT sets the Exit callback (executed at stop/kill)
      if ischar(fcn) || iscell(fcn) || isa(fcn, 'function_handle')
        for index=1:prod(size(obj))
          this = get_index(obj, index);
          if ~isvalid(this), continue; end
          this.StopFcn = fcn; % when killed
          this.EndFcn  = fcn; % when ends normally
        end
      end
    end % atexit
  end

end

% ------------------------------------------------------------------------------
% our timer functions
function refresh_fcn(tm, event, string_arg)

  obj = tm.UserData;
  refresh_Process(obj);
  if ~obj.isActive
    % process has ended by itself or aborted externally
    disp([ datestr(now) ': process ' obj.Name ' has ended.' ])
    feval(@exit_Process, obj, 'end');

  elseif ~isempty(obj.TimeOut) && obj.TimeOut > 0 ...
    && etime(clock, datevec(obj.creationDate)) > obj.TimeOut
    feval(@exit_Process,obj, 'timeout');
    
  end

end


function exit_fcn(tm, event, string_arg)
% called when the timer ends (stop)

  obj = tm.UserData;
  if obj.isActive && strcmp(get(obj.timer,'Running'),'on')
    stop(obj);
    exit_Process(obj, 'kill');  % kill
  end
end

function obj = get_index(pid, index)
  S.type='()'; S.subs = {index};
  obj = subsref(pid, S);
end

