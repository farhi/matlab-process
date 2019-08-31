function disp(s_in, name)
  % DISP display Process object (details)

  if nargin == 2 && ~isempty(name)
    iname = name;
  elseif ~isempty(inputname(1))
    iname = inputname(1);
  else
    iname = 'ans';
  end
   
  if length(s_in) > 1
    display(s_in, iname);
  else
    pid = s_in;
    refresh_Process(pid);
    if isdeployed || ~usejava('jvm'), id=class(s_in);
    else           id=[ '<a href="matlab:doc process">process</a> (<a href="matlab:methods process">methods</a>,<a href="matlab:help process">doc</a>,<a href="matlab:read(' iname ')">stdout</a>,<a href="matlab:exit(' iname ')">exit</a>)' ];
    end

    if pid.isActive, state='RUNNING'; else state='STOPPED'; end
    fprintf(1,'%s = %s object [%s]:\n',iname, id, state);

    s.Command      = num2str(pid.command);
    for f={'creationDate','terminationDate','exitValue','Duration','UserData', ...
      'info','StopFcn', 'EndFcn', 'TimerFcn', 'TimeOut'}
      s.(f{1}) = pid.(f{1});
    end
    s.period = period(pid);
    stdout = pid.stdout;
    stderr = pid.stderr;
    
    if isnumeric(s.creationDate),    s.creationDate=datestr(s.creationDate); end
    if isnumeric(s.terminationDate), s.terminationDate=datestr(s.terminationDate); end
    if isjava(pid.Runtime)
      fprintf(1, '            process: %s\n', char(pid.Runtime));
    else
      fprintf(1, '            process: %s\n', num2str(pid.Runtime));
    end
    disp(s);
    % now display stdout/stderr tail
    if isdeployed || ~usejava('jvm') || ~usejava('desktop')
      fprintf(1, '             stdout: [%s char]\n', num2str(numel(stdout)));
    else
      fprintf(1, ['             <a href="matlab:read(' iname ')">stdout</a>: [%s char]\n'], num2str(numel(stdout)));
    end
    if numel(stdout), fprintf(1, '%s\n', Process_disp_out(stdout)); end
    if numel(stderr)
      if isdeployed || ~usejava('jvm') || ~usejava('desktop')
        fprintf(1, '             stderr: [%s char]\n', num2str(numel(stderr)));
      else
        fprintf(1,[ '             <a href="matlab:error(' iname ')">stderr</a>: [%s char]\n'], num2str(numel(stderr)));
      end
      fprintf(1, '%s\n', Process_disp_out(stderr)); 
    end
  end
end

% ------------------------------------------------------------------------------
function out =  Process_disp_out(str)
  if isempty(str), out=''; return; end
  lines = strread(str,'%s','delimiter','\n\r');
  if numel(lines) > 4
    n = numel(lines);
    out = sprintf('%s\n...\n%s\n%s\n', lines{1}, lines{n-1}, lines{n});
  else
    out = sprintf('%s\n', lines{:});
  end
  out = deblank(out);
end

function obj = get_index(pid, index)
  S.type='()'; S.subs = {index};
  obj = subsref(pid, S);
end
