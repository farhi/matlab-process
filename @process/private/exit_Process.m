function ex=exit_Process(pid, action)
  % force to quit a running Process.
  if nargin < 2, action='end'; end

  if length(pid) > 1
    ex = nan;
    % can not kill an array.
    return
  end
  
  if ~isvalid(pid) || isempty(pid.timer) || ~isvalid(pid.timer), ex=nan; return; end
  
  % stop the timer but leaves the object. 
  if ~isempty(pid.timer) && isvalid(pid.timer) && strcmp(get(pid.timer,'Running'),'on'); 
    stop(pid.timer);
  end 

  % if the process is still running, kill it.
  if ~isempty(pid.Runtime) && pid.isActive
    if isjava(pid.Runtime)                             % DESTROY / KILL here
      p=pid.Runtime;
      p.destroy;
      pause(1) % wait a little for process to abort
    else
      % kill an external PID
      kill_external(pid.Runtime);  % private below
    end
    
    if isjava(pid.Runtime)
      try
        p=pid.Runtime;
        pid.exitValue = p.exitValue;
      catch
        % process is invalid (closed)
      end
    end
  end
  
  % collect last stdout/stderr
  if ~isempty(pid.Runtime)
    refresh_Process(pid); % flush stdout/stderr
    pid.Runtime = [];
  end
  
  % make sure we have measured the exec time
  if isempty(pid.terminationDate) || ~pid.terminationDate
    pid.terminationDate=now;
    % compute Duration
    pid.Duration = etime(clock, datevec(pid.creationDate));
  end
  % set return value
  ex = pid.exitValue;
  
  % when active, we execute the Callback (only once)
  if strcmp(action,'kill') || strcmp(action,'timeout')
    Callback = pid.StopFcn;
  elseif strcmp(action,'end')
    Callback = pid.EndFcn;
  else Callback = '';
  end
  % display message
  if strcmp(action,'timeout')
    toadd = [ datestr(now) ': Process ' pid.Name ' has reached its TimeOut ' num2str(pid.TimeOut) ' [s]' ];
    disp(toadd);
    pid.stderr = strcat(pid.stderr, sprintf('\n'), toadd, sprintf('\n'));
  elseif strcmp(action,'kill')
    toadd = [ datestr(now) ': Process ' pid.Name ' is requested to stop.' ];
    if pid.isActive, disp(toadd); end
    pid.stderr = strcat(pid.stderr, sprintf('\n'), toadd, sprintf('\n'));
  end

  pid.isActive = 0;
  istop = exec_Callback(pid, Callback, action);
  notify(pid, 'processEnded');
end

% ------------------------------------------------------------------------------
function kill_external(pid)
% kill an external PID
  if ~isempty(pid)
    if isnumeric(pid)
      for index=1:numel(pid)
        if ispc
          cmd=sprintf('taskkill /PID %i /F', pid(index));
        else
          cmd=sprintf('kill %i', pid(index));  % kill from PID
        end
        disp(cmd)
        system(cmd);
      end
    elseif ischar(pid.Runtime)
      if ispc
        cmd=sprintf('taskkill /im /f %s', pid);
      else
        cmd=sprintf('pkill %s', pid); % kill from name
      end
      disp(cmd)
      system(cmd);
    end
  end
end
