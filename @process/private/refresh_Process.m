function refresh_Process(pid)
  % check if a Process is still running. Collects its stdout/stderr.
  if length(pid) > 1
    % can not refresh an array.
    return
  end
  
  if ~isvalid(pid) || isempty(pid.timer) || (isa(pid.timer,'timer') && ~isvalid(pid.timer)), return; end
  if isempty(pid.Runtime), return; end
  
  if isjava(pid.Runtime)
    pid = refresh_Process_java(pid);
  else
    pid = refresh_Process_external(pid);
  end
  
  % compute Duration
  pid.Duration = etime(clock, datevec(pid.creationDate));

  status = pid.isActive;
  
  % when active, we execute the Callback
  if status
    Callback = pid.TimerFcn;
    istop = exec_Callback(pid, Callback, 'refresh');
  end
  notify(pid, 'processUpdate');

% ------------------------------------------------------------------------------
function pid = refresh_Process_java(pid)
  % test for a Java RunTime process (PID or command name)
  try
    pid.exitValue = pid.Runtime.exitValue; % will raise error if process still runs
    if isempty(pid.terminationDate) || ~pid.terminationDate
      pid.terminationDate=now;
    end
    pid.isActive  = 0;
  catch ME
    % still running
    if isempty(pid.Runtime) || ~isjava(pid.Runtime)
      pid.isActive  = 0;
    else
      pid.isActive  = 1;
    end
  end
  
  % then retrieve any stdout/stderr content (possibly in Buffer after end of process)
  if isjava(pid.stdinStream)
    if pid.interactive, method = 'slow'; else method = 'fast'; end
    toadd = process_get_output(pid.stdinStream, method);
    pid.stdout = sprintf('%s%s', pid.stdout, toadd);
    if pid.Monitor && ~isempty(toadd), disp([ pid.Name ': ' toadd ]); end
    
    toadd = process_get_output(pid.stderrStream, method);
    pid.stderr = sprintf('%s%s', pid.stderr, toadd);
    if pid.Monitor && ~isempty(toadd), disp([ pid.Name ': ' toadd ]); end
    
  else
    pid.stdinStream = [];
    pid.stdoutStream= [];
  end

% ------------------------------------------------------------------------------
function pid = refresh_Process_external(pid)

  % test for an external process (PID or command name)
  
  [PID, command] = get_command(pid);
  
  if isnan(PID), return; end  % warning: could not get the PID from task list
  
  if isempty(PID) && isempty(command)
    pid.isActive  = 0;
    pid.exitValue = 1;
  else
    pid.isActive  = 1;
    pid.exitValue = nan;
  end
  pid.Runtime = PID;
  if ~isempty(command)
    toadd = sprintf('%s\n', command{:});
    pid.stdout = sprintf('%s%s', pid.stdout, toadd);
    if pid.Monitor && ~isempty(toadd), disp([ pid.Name ': ' toadd ]); end
  end



